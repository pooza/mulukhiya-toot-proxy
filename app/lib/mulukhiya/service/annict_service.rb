module Mulukhiya
  class AnnictService
    include Package
    include SNSMethods

    attr_reader :timestamps, :sns

    def initialize(token = nil, guest: true)
      @token = token.decrypt rescue token
      @guest = guest
      @timestamps = AnnictTimestampStorage.new
      @sns = sns_class.new
    end

    def guest?
      return @guest == true
    end

    def viewers_works?
      return false if guest?
      return false unless config['/service/annict/browser/viewer/works']
      return true
    end

    def activities(&block)
      return enum_for(__method__) unless block
      query(:activity).dig('data', 'viewer', 'activities', 'edges')
        .filter_map {|activity| activity['item']}
        .select {|node| node['__typename'].present?}
        .select {|node| node['createdAt'].present?}
        .each(&block)
    end

    def account
      @account ||= self.class.create_viewer_info(query(:account).dig('data', 'viewer'))
      @account ||= {}
      return @account
    end

    def works(keyword = nil)
      titles = keyword.split(/\s+/) if keyword.present?
      titles = self.class.keywords unless titles.present?
      return [] unless titles.present?
      works = query(:works, {titles:}).dig('data', 'searchWorks', 'edges').map do |work|
        self.class.create_work_info(work['node'])
      end
      works.concat(account[:works]) if viewers_works?
      works.uniq! {|v| v['annictId']}
      return works.sort_by {|v| (v['seasonYear'].to_i * 100_000) + v['annictId']}.reverse
    end

    def episodes(ids)
      entries = query(:episodes, {ids:}).dig('data', 'searchWorks', 'nodes')
      return [] unless entries.is_a?(Array) && entries.any?
      all_episodes = entries.flat_map do |work|
        work.dig('episodes', 'nodes').map {|ep| ep.merge('work_annict_id' => work['annictId'])}
      end
      work_title = entries.first['title']
      return Parallel.map(all_episodes, in_threads: Parallel.processor_count * 2) do |episode|
        enrich_episode(episode, work_title)
      end.compact
    end

    def enrich_episode(episode, work_title)
      return nil unless subtitle = episode['title']
      episode = episode.dup
      episode['title'] = self.class.trim_ruby(subtitle) if self.class.subtitle_trim_ruby?
      return episode.merge(
        'hashtag' => episode['title'].to_hashtag,
        'hashtag_uri' => sns.create_tag_uri(episode['title']),
        'url' => self.class.create_episode_uri(episode['work_annict_id'], episode['annictId']),
        'command_toot' => self.class.create_command_toot(
          title: work_title,
          subtitle: episode['title'],
          number_text: episode['numberText'],
          minutes: config['/webui/episode/minutes'],
        ),
      )
    end

    def create_record(episode_id:, comment: nil, rating_state: nil)
      variables = {
        episodeId: resolve_episode_node_id(episode_id),
        comment:,
        ratingState: rating_state,
      }.compact
      response = annict_query!(:create_record, variables)
      return response.dig('data', 'createRecord', 'record')
    end

    # rubocop:disable Metrics/ParameterLists
    def create_review(work_id:, body:, rating_overall_state: nil, rating_animation_state: nil,
      rating_music_state: nil, rating_story_state: nil, rating_character_state: nil,
      share_twitter: nil, share_facebook: nil)
      variables = {
        workId: resolve_work_node_id(work_id),
        body:,
        ratingOverallState: rating_overall_state,
        ratingAnimationState: rating_animation_state,
        ratingMusicState: rating_music_state,
        ratingStoryState: rating_story_state,
        ratingCharacterState: rating_character_state,
        shareTwitter: share_twitter,
        shareFacebook: share_facebook,
      }.compact
      response = annict_query!(:create_review, variables)
      return response.dig('data', 'createReview', 'review')
    end
    # rubocop:enable Metrics/ParameterLists

    # createReview は workId に Relay グローバルノード ID を要求する。capsicum /
    # 番組表が扱うのは数値 annictId なので、resolve_episode_node_id と同じ要領で
    # 数値 workId を node ID へ解決する (#4339 と同じ落とし穴の予防)。
    def resolve_work_node_id(annict_id)
      annict_id = annict_id.to_i
      response = annict_query!(:resolve_work, {annictIds: [annict_id]})
      nodes = response.dig('data', 'searchWorks', 'nodes')
      node = Array(nodes).find {|n| n.is_a?(Hash) && n['annictId'].to_i == annict_id}
      unless node&.dig('id').present?
        raise Ginseng::NotFoundError, "Annict work not found: #{annict_id}"
      end
      return node['id']
    end

    # Annict GraphQL の createRecord は episodeId に Relay グローバルノード ID
    # (Base64) を要求し、数値 annictId をそのまま渡すと `Invalid input` で弾く。
    # capsicum / 番組表が扱うのは数値 annictId なので、ここで node ID へ解決する。
    def resolve_episode_node_id(annict_id)
      annict_id = annict_id.to_i
      response = annict_query!(:resolve_episode, {annictIds: [annict_id]})
      nodes = response.dig('data', 'searchEpisodes', 'nodes')
      node = Array(nodes).find {|n| n.is_a?(Hash) && n['annictId'].to_i == annict_id}
      unless node&.dig('id').present?
        raise Ginseng::NotFoundError, "Annict episode not found: #{annict_id}"
      end
      return node['id']
    end

    # query を実行し、Annict 由来の auth/scope 失敗を AuthError (403) に
    # 正規化する。Annict は write 権限不足トークンを HTTP 401/403
    # (Ginseng::HTTP が GatewayError "Bad response 40x" に変換) で返すことも、
    # 200 + GraphQL errors で返すこともあるため、capsicum には「要(再)連携」を
    # 403 一本で見せられるようここで吸収する (扱いやすいプロキシの責務)。
    def annict_query!(template, variables)
      response = begin
        query(template, variables)
      rescue Ginseng::GatewayError => e
        if /Bad response (401|403)/.match?(e.message.to_s)
          raise Ginseng::AuthError, 'Annict authorization required'
        end
        raise
      end
      raise Ginseng::GatewayError, 'Unexpected Annict GraphQL response' unless response.is_a?(Hash)
      if response['errors'].present?
        errors = response['errors']
        message = format_graphql_errors(errors)
        if /unauthor|forbidden|scope|token|permission|credential/i.match?(message)
          raise Ginseng::AuthError, 'Annict authorization required'
        end
        raise classify_graphql_error(errors, message), message
      end
      return response
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
      if spoiler?(body_template) || bad?(values)
        body[:text] = body_template.to_s.lstrip
        body[:spoiler_text] = [
          title_template.to_s.tr("\n", ' ').strip,
          spoiler?(body_template) ? config['/service/annict/review/suffixes/spoiler'] : '',
          bad?(values) ? config['/service/annict/review/suffixes/bad'] : '',
        ].join
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
        @rest_service.base_uri = config['/service/annict/urls/api/rest']
      end
      return @rest_service
    end

    def graphql_service
      unless @graphql_service
        @graphql_service = HTTP.new
        @graphql_service.base_uri = config['/service/annict/urls/api/graphql']
      end
      return @graphql_service
    end

    def service
      unless @service
        @service = HTTP.new
        @service.base_uri = config['/service/annict/urls/default']
      end
      return @service
    end

    def auth(code)
      return service.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => config['/service/annict/oauth/redirect_uri'],
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
        redirect_uri: config['/service/annict/oauth/redirect_uri'],
        scope: self.class.oauth_scopes.join(' '),
      }
      return uri
    end

    def self.create_viewer_info(viewer)
      return {} unless viewer
      viewer = viewer.clone.deep_symbolize_keys
      viewer[:id] = viewer[:annictId]
      viewer[:avatar_uri] = Ginseng::URI.parse(viewer[:avatarUrl]) if viewer[:avatar_uri]
      if nodes = viewer.dig(:works, :nodes)
        viewer[:works] = nodes
          .select {|node| node[:viewerStatusState] == 'WATCHING'}
          .map {|node| create_work_info(node)}
      end
      viewer[:works] ||= []
      return viewer
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
      return config['/service/annict/episodes/ruby/trim'] == true
    end

    def self.ruby_pattern
      return Regexp.new(config['/service/annict/episodes/ruby/pattern'])
    end

    def self.trim_ruby(title)
      return title.gsub(ruby_pattern, '').strip
    end

    def self.oauth_scopes(key = 'default')
      return config["/service/annict/oauth/scopes/#{key}"]
    end

    def self.client_id
      return config['/service/annict/oauth/client/id'] rescue nil
    end

    def self.client_secret
      return config['/service/annict/oauth/client/secret'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/service/annict/oauth/client/secret']
    end

    def self.keywords
      return config['/service/annict/works'] || []
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

    def self.create_episode_uri(work_id, episode_id)
      return nil unless work_id.present? && episode_id.present?
      return create_record_uri(work_id, episode_id)
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
        .select {|id| annict_token?(storage[id])}
        .filter_map {|id| Environment.account_class[id] rescue nil}
        .select(&:webhook)
        .select(&:annict)
        .reject(&:bot?)
        .each(&block)
    end

    def self.create_command_toot(params = {})
      command = {
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
      }
      if Environment.misskey_type? && params[:minutes]
        command[:decoration] = {minutes: params[:minutes]}
      end
      return command.to_yaml
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

    def self.annict_token?(config)
      return config['/service/annict/token'] || config['/annict/token']
    end

    private

    def spoiler?(str)
      return str.to_s.match?(config['/spoiler/pattern'])
    end

    def bad?(values)
      return (values[:ratingOverallState] || values[:ratingState]).to_s.upcase == 'BAD'
    end

    def crawlable?(activity, params)
      keywords = self.class.keywords
      return true unless keywords.present?
      return true unless account = params[:account]
      return true unless account.user_config['/service/annict/theme_works_only']
      return keywords.any? {|v| activity.to_json.include?(v)}
    end

    def format_graphql_errors(errors)
      messages = Array(errors).filter_map {|e| e.is_a?(Hash) ? e['message'] : e.to_s}
      return messages.join('; ').presence || 'Annict GraphQL error'
    end

    # Annict GraphQL の errors を HTTP セマンティクスへ寄せて分類する (Y3)。
    # errors[].extensions.code があれば優先し、なければ message のパターンで
    # 判定。クライアント起因 (404/422) を 502 に丸めず capsicum 側で
    # 区別できるようにする。auth 系は呼び出し元で先に AuthError へ正規化済み。
    def classify_graphql_error(errors, message)
      codes = Array(errors).filter_map do |e|
        e.dig('extensions', 'code').to_s.upcase.presence if e.is_a?(Hash)
      end
      if codes.include?('NOT_FOUND') || /not found|does not exist|no such/i.match?(message)
        return Ginseng::NotFoundError
      end
      if codes.any? {|c| /ARGUMENT|VALIDATION|INVALID|UNPROCESSABLE|BAD_REQUEST/.match?(c)} ||
          /invalid|validation|must be|argument/i.match?(message)
        return Ginseng::ValidateError
      end
      return Ginseng::GatewayError
    end

    def query(template, variables = nil)
      query = File.read(File.join(Environment.dir, 'app/query/annict', "#{template}.graphql"))
      variables&.deep_stringify_keys!
      body = {query:, variables:}.compact
      endpoint = Ginseng::URI.parse(config['/service/annict/urls/api/graphql'])
      response = graphql_service.post(endpoint.path, {
        body: body.to_json,
        headers: {Authorization: "Bearer #{@token}"},
        timeout: config['/service/annict/timeout'],
      }).parsed_response
      # Annict が 200 OK で JSON 以外 (HTML/プレーンテキスト) を返すケースで
      # response.dig が NoMethodError を起こす経路を防ぐ。account 反映は
      # 期待通り Hash の時のみ行い、戻り値はそのまま呼び元に渡して個別判断させる
      if response.is_a?(Hash) && !guest?
        @account = self.class.create_viewer_info(response.dig('data', 'viewer'))
      end
      return response
    end
  end
end
