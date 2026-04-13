module Mulukhiya
  class APIController < Controller
    get '/about' do
      sns.token ||= sns.default_token
      about = config.about
      about[:config][:theme] = {color: sns.theme_color}
      about[:config][:handlers] = (Handler.all_names || [])
        .reject {|name| config["/handler/#{name}/disable"] == true rescue false}
        .sort.to_a
      @renderer.message = about
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/health' do
      sns.token ||= sns.default_token
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      sns.account.user_config.token = token
      @renderer.message = {
        account: sns.account.to_h,
        config: sns.account.user_config.to_h,
        webhook: {url: sns.account.webhook.uri.to_s},
        token: sns.access_token.to_h.except(:account),
        visibility_names: parser_class.visibility_names,
      }
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/config/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      Handler.create(:user_config_command).handle_toot(params, {sns:})
      @renderer.message = {config: sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/mastodon/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.mastodon_type?
      errors = MastodonAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = sns.auth(params[:code], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = @renderer.message['access_token'].encrypt
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/misskey/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = sns.auth(params[:code], params[:type])
        token = sns.create_access_token(response.parsed_response['accessToken'], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = token.encrypt
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/emoji/palettes' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = sns.emoji_palettes(sns.account)
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/decoration/list' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.decoration?
      sns.token ||= sns.default_token
      @renderer.message = sns.fetch_avatar_decorations
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/decoration/restore' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.decoration?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      saved = sns.account.user_config['/decoration/saved_state']
      raise Ginseng::NotFoundError, 'Not Found' unless saved.present?
      DecorationInitializeWorker.new.restore_decoration(sns.account)
      @renderer.message = {config: sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      sns.token ||= sns.default_token
      @renderer.message = Program.instance.data
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/program/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      ProgramUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program/works' do
      annict = sns.account&.annict || account_class.info_account.annict
      raise Ginseng::AuthError, 'Unauthorized' unless annict
      errors = AnnictWorkListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = annict.works(params[:q]).map do |work|
          values = work.deep_symbolize_keys
          values[:officialSiteUrl] = values[:officialSiteUrl].to_s if values[:officialSiteUrl]
          values
        end
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program/works/:id/episodes' do
      raise Ginseng::AuthError, 'Unauthorized' unless annict = account_class.info_account.annict
      @renderer.message = annict.episodes([params[:id].to_i]).map do |episode|
        episode.merge(
          url: episode['url'].to_s,
          hashtag_url: episode['hashtag_uri'].to_s,
          command_toot: episode['command_toot'],
        )
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.media_catalog?
      sns.token ||= sns.default_token
      params[:page] = (params[:page] || 1).to_i unless params[:cursor]
      params[:only_person] = (params[:only_person] || 0).to_i.zero? ? 0 : 1
      params.delete(:q) unless params[:q].present?
      params.delete(:q) unless sns.account
      errors = MediaListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      elsif controller_class.media_catalog?
        params[:rule] = SearchRule.new(params[:q]) if params[:q]
        @renderer.message = attachment_class.catalog(params)
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/file/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      MediaCleaningWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/metadata/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      MediaMetadataStorage.new.clear
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/status/list' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.account_timeline?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      params[:limit] ||= config['/webui/status/timeline/limit']
      params[:page] = (params[:page] || 1).to_i
      params[:self] = (params[:self] || 0).to_i.zero? ? 0 : 1
      params.delete(:q) unless params[:q].present?
      errors = StatusListContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        params[:rule] = SearchRule.new(params[:q]) if params[:q]
        @renderer.message = sns.account.statuses(params)
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/status/:id' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      @renderer.message = status.to_h.merge(
        account: status.account.to_h.slice(:username, :display_name, :acct),
      )
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/status/tags' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.repost?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      errors = StatusTagsContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        status.parser.footer_tags.clear
        status.parser.footer_tags.concat(params[:tags])
        body = [
          status.parser.body,
          '',
          status.parser.footer_tags.map(&:to_hashtag).join(' '),
        ].join("\n")
        @renderer.message = sns.repost(status, body)
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    put '/scheduled_status/:id/tags' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.mastodon_type?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      storage = ScheduledStatusStorage.new
      entry = storage.get(params[:id])
      raise Ginseng::NotFoundError, 'Not Found' unless entry
      raise Ginseng::AuthError, 'Unauthorized' unless entry[:account_id] == sns.account.id
      errors = ScheduledStatusTagsContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        saved_params = entry[:params].deep_stringify_keys
        original_body = saved_params[status_field]
        parser = parser_class.new(original_body)
        body = [
          parser.body,
          '',
          params[:tags].map(&:to_hashtag).join(' '),
        ].join("\n")
        saved_params[status_field] = body
        delete_response = sns.delete_scheduled_status(params[:id])
        unless delete_response.code.between?(200, 299)
          message = delete_response.parsed_response&.dig('error') || 'delete failed'
          raise Ginseng::GatewayError, message
        end
        response = sns.toot(saved_params.merge(
          'scheduled_at' => entry[:scheduled_at],
        ).compact)
        if response.code.between?(200, 299)
          new_entry = response.parsed_response
          storage.unlink(params[:id])
          margin = ScheduledStatusSaveHandler::MARGIN
          expires_in = (Time.parse(new_entry['scheduled_at']) - Time.now).to_i
          ttl = [expires_in + margin, margin].max
          storage.set(new_entry['id'], {
            account_id: sns.account.id,
            params: saved_params,
            scheduled_at: new_entry['scheduled_at'],
          }, ttl:)
          @renderer.message = {
            id: new_entry['id'],
            scheduled_at: new_entry['scheduled_at'],
            tags: params[:tags],
          }
        else
          saved_params[status_field] = original_body
          sns.toot(saved_params.merge('scheduled_at' => entry[:scheduled_at]).compact)
          message = response.parsed_response['error'] || 'recreate failed'
          raise Ginseng::GatewayError, message
        end
      end
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.log
      @renderer.status = e.respond_to?(:source_status) ? e.source_status : 502
      @renderer.message = {error: e.message}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/status/nowplaying' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      raise Ginseng::NotFoundError, 'Not Found' unless body = status.parser.body
      errors = StatusContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        @renderer.message = sns.repost(status, NowplayingHandler.trim(body))
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    put '/status/poipiku' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account.webhook
      errors = StatusContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        parser = parser_class.new(status.text)
        tags = parser.tags.clone
        tags.push(config['/handler/poipiku_image/fanart_tag']) if params[:fanart]
        @renderer.message = sns.account.webhook.post(
          text: [parser.body, tags.to_s].join("\n"),
          visibility: status.visibility_name,
        ).response
        sns.delete_status(status.id)
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/annict/oauth_uri' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      @renderer.message = {oauth_uri: AnnictService.new.oauth_uri.to_s}
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/annict/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = AnnictService.new.auth(params[:code])
        sns.account.user_config.update(service: {annict: {token: response['access_token']}})
        sns.account.annict.clear
        sns.account.annict.updated_at = Time.now
        @renderer.status = response.code
        @renderer.message = {config: sns.account.user_config.to_h}
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/announcement/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.announcement?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      AnnouncementWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/tagging/favorites' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.favorite_tags?
      sns.token ||= sns.default_token
      @renderer.message = hash_tag_class.favorites
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/dic/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      TaggingDictionaryUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/tagging/dic/annict/episodes' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless annict = account_class.info_account.annict
      episodes = annict.episodes(annict.works.map {|v| v['annictId'].to_i})
      @renderer.message = episodes.filter_map do |e|
        title = e['title'].to_s.strip
        next if title.empty?
        if (m = e['numberText'].to_s[/\d+/])
          [title, ["#{m}話"]]
        else
          [title, []]
        end
      end.to_h
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/tag/search' do
      tags = {}
      errors = TagSearchContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        dic = TaggingDictionary.new
        dic.cache.each do |entry|
          word = entry.shift
          next unless params[:q].match?(entry.first[:regexp])
          tags[word] = entry.first
          tags[word][:word] = word
          tags[word][:short] = dic.short?(word)
          tags[word][:words].unshift(word)
          tags[word][:tags] = TagContainer.new(tags.dig(word, :words)).create_tags
        rescue => e
          e.log(entry:)
        end
        @renderer.message = tags
      end
      return @renderer.to_s
    end

    post '/tagging/usertag/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      UserTagInitializeWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/piefed/communities' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.piefed?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = sns.account.piefed&.communities || {}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/feed/list' do
      tags = TagContainer.new
      tags.merge(TagContainer.default_tags)
      tags.merge(TagContainer.media_tags)
      if sns.account
        tags.merge(sns.account.featured_tags)
        tags.merge(sns.account.followed_tags)
        tags.merge(sns.account.field_tags)
        tags.merge(sns.account.bio_tags)
      end
      @renderer.message = tags.map {|t| hash_tag_class.get(tag: t).to_h}.deep_compact
      return @renderer.to_s
    end

    post '/feed/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      FeedUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/admin/handler/list' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      @renderer.message = Handler.all.map do |handler|
        {
          name: handler.underscore,
          disable: config.disable?(handler),
          schema: handler.editable_schema,
          params: handler.editable_params,
        }
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/handler/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      if params.key?(:flag)
        config.update_file(handler: {params[:handler] => {disable: params[:flag]}})
      elsif params.key?(:values)
        handler = Handler.create(params[:handler])
        validated = handler.validate_params(params[:values])
        config.update_file(handler: {params[:handler] => validated})
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/admin/config/audit' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      @renderer.message = config.audit
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/agent/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      if params[:info_token]
        raise Ginseng::AuthError, 'Unauthorized' unless sns.account.admin? || sns.account.info?
        config.update_file(agent: {info: {token: params[:info_token]}})
      end
      if params[:test_token]
        raise Ginseng::AuthError, 'Unauthorized' unless sns.account.admin? || sns.account.test?
        config.update_file(agent: {test: {token: params[:test_token]}})
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/puma/restart' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.admin?
      PumaDaemonRestartWorker.perform_in(config['/puma/restart/seconds'], {})
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/account/is_cat' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = IsCatContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
        return @renderer.to_s
      end
      storage = IsCatStorage.new
      http = HTTP.new
      result = Concurrent::Hash.new
      Parallel.each(params[:accts].uniq, in_threads: Parallel.processor_count) do |acct_str|
        acct = Ginseng::Fediverse::Acct.new(acct_str)
        cached = storage.get(acct_str)
        if cached
          result[acct_str] = cached['is_cat']
          next
        end
        actor = fetch_actor(http, acct)
        is_cat = actor&.dig('isCat')
        result[acct_str] = is_cat
        storage.set(acct_str, {is_cat:}) unless actor.nil?
      rescue => e
        e.log(acct: acct_str)
        result[acct_str] = nil
      end
      @renderer.message = result
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def token
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return params[:token].decrypt
    rescue
      return params[:token]
    end

    def self.default_type
      return 'application/json; charset=UTF-8'
    end

    private

    def fetch_actor(http, acct)
      return nil unless valid_remote_host?(acct.host)
      webfinger = http.get(
        "https://#{acct.host}/.well-known/webfinger?resource=acct:#{acct}",
        {headers: {'Accept' => 'application/jrd+json'}},
      ).parsed_response
      actor_uri = webfinger['links']&.find do |l|
        l['type'] == 'application/activity+json'
      end&.dig('href')
      return nil unless actor_uri
      actor_host = Ginseng::URI.parse(actor_uri)&.host
      return nil unless valid_remote_host?(actor_host)
      return http.get(
        actor_uri,
        {headers: {'Accept' => 'application/activity+json'}},
      ).parsed_response
    rescue
      return nil
    end

    def valid_remote_host?(host)
      return false unless host.present?
      return false unless host.include?('.')
      return false if host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/)
      return false if host.match?(/\A\[.*\]\z/)
      addrs = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)
      addrs.none? do |ip|
        addr = IPAddr.new(ip)
        addr.private? || addr.loopback? || addr.link_local?
      end
    rescue
      return false
    end
  end
end
