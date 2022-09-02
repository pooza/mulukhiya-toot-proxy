module Mulukhiya
  class AnnictService
    include Package
    include SNSMethods
    attr_reader :timestamps

    def initialize(token = nil)
      @token = (token.decrypt rescue token)
      @timestamps = AnnictTimestampStorage.new
    end

    def activities(&block)
      return enum_for(__method__) unless block
      response = query(file: :activity)
      @account ||= {
        id: response.dig('data', 'viewer', 'annictId'),
        name: response.dig('data', 'viewer', 'name'),
        username: response.dig('data', 'viewer', 'username'),
        avatar_uri: Ginseng::URI.parse(response.dig('data', 'viewer', 'avatarUrl')),
      }
      response.dig('data', 'viewer', 'activities', 'edges')
        .filter_map {|activity| activity['node']}
        .select {|node| node['__typename'].present?}
        .select {|node| node['createdAt'].present?}
        .each(&block)
    end

    def account
      unless @account
        response = query(file: :account)
        @account = {
          id: response.dig('data', 'viewer', 'annictId'),
          name: response.dig('data', 'viewer', 'name'),
          username: response.dig('data', 'viewer', 'username'),
          avatar_uri: Ginseng::URI.parse(response.dig('data', 'viewer', 'avatarUrl')),
        }
      end
      return @account
    end

    def works
      template = Template.new(File.join(Environment.dir, 'app/query/annict/works.graphql.erb'))
      return config['/annict/works'].inject([]) do |entries, title|
        template[:title] = title
        entries.concat(query(raw: template.to_s).dig('data', 'searchWorks', 'edges').map do |work|
          url = work.dig('node', 'officialSiteUrl')
          if url.present?
            work['node']['officialSiteUrl'] = Ginseng::URI.parse(url)
          else
            work['node'].delete('officialSiteUrl')
          end
          work['node']
        end)
      end
    end

    def episodes(id)
      template = Template.new(File.join(Environment.dir, 'app/query/annict/episodes.graphql.erb'))
      template[:work_id] = id
      return unless work = query(raw: template.to_s).dig('data', 'searchWorks', 'nodes').first
      return work.dig('episodes', 'nodes')
    end

    def crawl(params = {})
      return unless webhook = params[:webhook]
      touch unless updated_at
      recent = activities.select {|v| updated_at < Time.parse(v['createdAt'])}
      return unless recent.present?
      recent.each {|avtivity| webhook.post(create_payload(avtivity))}
      touch
      return recent
    end

    def create_payload(values)
      values.deep_symbolize_keys!
      type = values[:__typename].underscore.to_sym
      body_template = Template.new("annict/#{type}_body")
      body_template[type] = values
      title_template = Template.new("annict/#{type}_title")
      title_template[type] = values
      body = {text: [title_template.to_s, body_template.to_s].join}
      if body_template.to_s.match?(config['/spoiler/pattern'])
        body[:text] = body_template.to_s.lstrip
        body[:spoiler_text] = "#{title_template.to_s.tr("\n", ' ').strip} （ネタバレ）"
      end
      return SlackWebhookPayload.new(body)
    end

    def updated_at
      @updated_at ||= Time.parse(timestamps[account[:id]]['time']).getlocal
      return @updated_at
    rescue => e
      e.log
      return nil
    end

    def updated_at=(time)
      time = Time.parse(time.to_s).getlocal
      timestamps[account[:id]] = {time: time.to_s} if updated_at.nil? || (updated_at < time)
      @updated_at = nil
    end

    def touch
      self.updated_at = Time.now
    end

    def rest_service
      unless @rest_service
        @rest_service = HTTP.new
        @rest_service.base_uri = config['/annict/urls/api/rest']
      end
      return @rest_service
    end

    def graphql_service
      unless @graphql_service
        @graphql_service = HTTP.new
        @graphql_service.base_uri = config['/annict/urls/api/graphql']
      end
      return @graphql_service
    end

    def service
      unless @service
        @service = HTTP.new
        @service.base_uri = config['/annict/urls/default']
      end
      return @service
    end

    def auth(code)
      return service.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => config['/annict/oauth/redirect_uri'],
          'client_id' => self.class.client_id,
          'client_secret' => self.class.client_secret,
          'code' => code,
        },
      })
    end

    def oauth_uri
      uri = service.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: self.class.client_id,
        response_type: 'code',
        redirect_uri: config['/annict/oauth/redirect_uri'],
        scope: self.class.oauth_scopes.join(' '),
      }
      return uri
    end

    def self.oauth_scopes(key = 'default')
      return config["/annict/oauth/scopes/#{key}"]
    end

    def self.client_id
      return config['/annict/oauth/client/id'] rescue nil
    end

    def self.client_secret
      return config['/annict/oauth/client/secret'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/annict/oauth/client/secret']
    end

    def self.config?
      return false if client_id.nil?
      return false if client_secret.nil?
      return true
    end

    def self.create_record_uri(work_id, episode_id)
      return new.service.create_uri("/works/#{work_id}/episodes/#{episode_id}")
    end

    def self.create_review_uri(work_id)
      return new.service.create_uri("/works/#{work_id}/records")
    end

    def self.create_episode_number_text(str)
      return unless str
      return str unless match = str.match(/[[:digit:]][.[:digit:]]*/)
      return "#{match}話"
    end

    def self.accounts(&block)
      return enum_for(__method__) unless block
      storage = UserConfigStorage.new
      storage.all_keys
        .map {|key| key.split(':').last}
        .select {|id| storage[id]['/annict/token']}
        .filter_map {|id| Environment.account_class[id] rescue nil}
        .select(&:webhook)
        .select(&:annict)
        .reject(&:bot?)
        .each(&block)
    end

    def self.crawl_all(params = {})
      return unless controller_class.annict?
      bar = ProgressBar.create(total: accounts.count)
      results = {}
      accounts.each do |account|
        results[account.acct.to_s] = account.annict.crawl(params.merge(webhook: account.webhook))
      rescue => e
        e.log(acct: account.acct.to_s)
      ensure
        bar&.increment
      end
      bar&.finish
      return unless Environment.rake?
      results.each do |acct, result|
        puts({acct:, result:}.to_yaml)
      end
    end

    private

    def query(params)
      case params
      in {raw: raw}
        query = raw
      in {file: file}
        query = File.read(File.join(Environment.dir, "app/query/annict/#{file}.graphql"))
      end
      return graphql_service.post(Ginseng::URI.parse(config['/annict/urls/api/graphql']).path, {
        body: {query:},
        headers: {Authorization: "Bearer #{@token}"},
      }).parsed_response
    end
  end
end
