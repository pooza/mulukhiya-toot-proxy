module Mulukhiya
  class AnnictService
    include Package
    include SNSMethods
    attr_reader :timestamps, :sns

    def initialize(token = nil)
      @token = (token.decrypt rescue token)
      @timestamps = AnnictTimestampStorage.new
      @sns = sns_class.new
    end

    def activities(&block)
      return enum_for(__method__) unless block
      query(:activity).dig('data', 'viewer', 'activities', 'edges')
        .filter_map {|activity| activity['node']}
        .select {|node| node['__typename'].present?}
        .select {|node| node['createdAt'].present?}
        .each(&block)
    end

    def account
      @account ||= self.class.create_viewer_info(query(:account).dig('data', 'viewer'))
      return @account
    end

    def works(keyword = nil)
      keywords = self.class.keywords unless keyword.present?
      keywords ||= [keyword]
      all = keywords.inject([]) do |entries, title|
        works = query(:works, {title:}).dig('data', 'searchWorks', 'edges').map do |work|
          self.class.create_work_info(work['node'])
        end
        entries.concat(works)
      end
      # all.concat(account[:works])
      all.uniq! {|v| v['annictId']}
      return all.sort_by {|v| (v['seasonYear'] * 100_000) + v['annictId']}.reverse
    end

    def episodes(id)
      return unless entries = query(:episodes, {id:}).dig('data', 'searchWorks', 'nodes')
      all = []
      entries.map {|v| v.dig('episodes', 'nodes')}.each do |episodes|
        episodes.each do |episode|
          next unless subtitle = episode['title']
          episode['title'] = self.class.trim_ruby(subtitle) if self.class.subtitle_trim_ruby?
          all.push(episode.merge(
            'hashtag' => episode['title'].to_hashtag,
            'hashtag_uri' => sns.create_tag_uri(episode['title']),
            'command_toot' => self.class.create_command_toot(
              title: entries.first['title'],
              subtitle: episode['title'],
              number_text: episode['numberText'],
              minutes: config['/webui/episode/minutes'],
            ),
          ))
        end
      end
      return all
    end

    def crawl(params = {})
      return unless webhook = params[:webhook]
      touch unless updated_at
      recent = activities.select {|v| updated_at < Time.parse(v['createdAt'])}
      return unless recent.present?
      recent.select {|v| crawlable?(v, params)}.each do |activity|
        webhook.post(create_payload(activity))
      end
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
      return unless updated_at.nil? || (updated_at < time)
      @updated_at = nil
      timestamps[account[:id]] = {time: time.to_s}
      logger.info(annict: {id: account[:id], updated_at: time.to_s})
    end

    def clear
      timestamps.unlink(account[:id])
      logger.info(annict: {id: account[:id], updated_at: 'deleted'})
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

    def self.create_viewer_info(viewer)
      viewer = viewer.clone.deep_symbolize_keys
      return viewer.compact.merge(
        id: viewer[:annictId],
        avatar_uri: Ginseng::URI.parse(viewer[:avatarUrl]),
        works: viewer.dig(:works, :nodes)
          .select {|node| node[:viewerStatusState] == 'WATCHING'}
          .map {|node| create_work_info(node)},
      )
    end

    def self.create_work_info(work)
      work.deep_stringify_keys!
      sns = sns_class.new
      url = work['officialSiteUrl']
      work['officialSiteUrl'] = url.present? ? Ginseng::URI.parse(url) : nil
      return work.compact.merge(
        'hashtag' => work['title'].to_hashtag,
        'hashtag_url' => sns.create_tag_uri(work['title']).to_s,
        'command_toot' => create_command_toot(title: work['title']),
      )
    end

    def self.subtitle_trim_ruby?
      return config['/annict/episodes/ruby/trim'] == true
    end

    def self.ruby_pattern
      return Regexp.new(config['/annict/episodes/ruby/pattern'])
    end

    def self.trim_ruby(title)
      return title.gsub(ruby_pattern, '').strip
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

    def self.keywords
      return config['/annict/works'] || []
    rescue
      return []
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

    def self.create_command_toot(params = {})
      return {
        command: 'user_config',
        tagging: {
          user_tags: [
            params[:title],
            '実況',
            'エア番組',
            create_episode_number_text(params[:number_text]),
            params[:subtitle],
          ].compact,
          minutes: params[:minutes],
        }.deep_compact,
      }.to_yaml
    end

    def self.crawl_all(params = {})
      return unless controller_class.annict?
      bar = ProgressBar.create(total: accounts.count)
      results = {}
      accounts.each do |account|
        results[account.acct.to_s] = account.annict.crawl(params.merge(
          webhook: account.webhook,
          account:,
        ))
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

    def crawlable?(activity, params)
      keywords = self.class.keywords
      return true unless keywords.present?
      return true unless account = params[:account]
      return true unless account.user_config['/annict/theme_works_only']
      return keywords.any? {|v| activity.to_json.include?(v)}
    end

    def query(template, params = {})
      path = File.join(Environment.dir, 'app/query/annict', "#{template}.graphql.erb")
      template = Template.new(path)
      template.params = params
      endpoint = Ginseng::URI.parse(config['/annict/urls/api/graphql'])
      response = graphql_service.post(endpoint.path, {
        body: {query: template.to_s},
        headers: {Authorization: "Bearer #{@token}"},
      }).parsed_response
      if viewer = response.dig('data', 'viewer')
        @account = self.class.create_viewer_info(viewer)
      end
      return response
    end
  end
end
