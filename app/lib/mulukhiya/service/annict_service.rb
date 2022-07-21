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
      self.updated_at ||= Time.now
      uri = Ginseng::URI.parse(config['/annict/urls/api/graphql'])
      response = graphql_service.post(uri.path, {
        body: {query: query(:activity)},
        headers: {Authorization: "Bearer #{@token}"},
      })
      @account = {id: response['annictId'], username: response['username']}
      response.parsed_response
        .dig('data', 'viewer', 'activities', 'edges')
        .filter_map {|activity| activity['node']}
        .select {|node| node['__typename'].present?}
        .select {|node| node['createdAt'].present?}
        .each(&block)
    end

    def query(name)
      return File.read(File.join(Environment.dir, "app/query/annict/#{name}.graphql"))
    end

    def create_payload(values)
      type = values['__typename'].underscore
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

    def account
      unless @account
        uri = Ginseng::URI.parse(config['/annict/urls/api/graphql'])
        response = graphql_service.post(uri.path, {
          body: {query: query(:account)},
          headers: {Authorization: "Bearer #{@token}"},
        }).parsed_response
        @account = {
          id: response.dig('data', 'viewer', 'annictId'),
          name: response.dig('data', 'viewer', 'name'),
          username: response.dig('data', 'viewer', 'username'),
          avatar_uri: Ginseng::URI.parse(response.dig('data', 'viewer', 'avatarUrl')),
        }
      end
      return @account
    end

    def crawl(params = {})
      return unless webhook = params[:webhook]
      recent = activities.select {|v| Time.parse(v['createdAt']) <= updated_at}
      return unless recent.present?
      recent.each {|v| webhook.post(create_payload(v))}
      self.updated_at = recent.map {|v| v['createdAt']}.max unless params[:dryrun]
      return recent
    end

    alias me account

    def updated_at
      @updated_at ||= Time.parse(timestamps[account[:id]]['time'])
      return @updated_at
    rescue
      return nil
    end

    def updated_at=(time)
      return if updated_at && Time.parse(time.to_s) < updated_at
      timestamps[account[:id]] = {time: time.to_s}
      @updated_at = nil
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

    def self.accounts
      return AnnictTimestampStorage.accounts
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
  end
end
