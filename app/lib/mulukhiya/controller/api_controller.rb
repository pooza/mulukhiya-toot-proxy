module Mulukhiya
  class APIController < Controller
    get '/about' do
      sns.token ||= sns.default_token
      @renderer.message = config.about
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
        filters: sns.filters&.parsed_response,
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

    post '/filter/add' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.filter?
      raise Ginseng::NotFoundError, 'Not Found' unless handler = Handler.create(:filter_command)
      handler.handle_toot(params, {sns:})
      @renderer.message = {filters: sns.filters}
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
      raise Ginseng::AuthError, 'Unauthorized' unless annict = account_class.info_account.annict
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
      @renderer.message = annict.episodes(params[:id]).map do |episode|
        episode.merge(
          url: episode['url'].to_s,
          hashtag_url: episode['hashtag_uri'].to_s,
          command_url: episode['command_uri'].to_s,
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
      params[:page] = (params[:page] || 1).to_i
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      MediaCleaningWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/metadata/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
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
        account: status.account.to_h.slice(:username, :display_name),
      )
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/status/tags' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.delete_and_tagging?
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
          status.parser.footer_tags.map(&:to_hashtag).join(' '),
        ].join("\n")
        @renderer.message = sns.update_status(status.id, body, {
          headers: {'X-Mulukhiya-Purpose' => "#{request.request_method} #{request.fullpath}"},
        })
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/status/tag' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.update_status?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      errors = StatusTagContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        tags = status.parser.footer_tags.push(params[:tag])
        body = [status.parser.body, tags.map(&:to_hashtag).join(' ')].join("\n")
        @renderer.message = sns.update_status(status.id, body, {
          headers: {'X-Mulukhiya-Purpose' => "#{request.request_method} #{request.fullpath}"},
        })
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    delete '/status/tag' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.update_status?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless tag = hash_tag_class.get(tag: params[:tag])
      raise Ginseng::AuthError, 'Default hashtags cannot be deleted.' unless tag.deletable?
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      errors = StatusTagContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        tags = status.parser.footer_tags.delete(tag.name)
        body = [status.parser.body, tags.map(&:to_hashtag).join(' ')].join("\n")
        @renderer.message = sns.update_status(status.id, body, {
          headers: {'X-Mulukhiya-Purpose' => "#{request.request_method} #{request.fullpath}"},
        })
      end
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
        @renderer.message = sns.update_status(status.id, NowplayingHandler.trim(body), {
          headers: {'X-Mulukhiya-Purpose' => "#{request.request_method} #{request.fullpath}"},
        })
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

    post '/annict/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        response = AnnictService.new.auth(params[:code])
        sns.account.user_config.update(annict: {token: response['access_token']})
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
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
      ids = annict.works.map {|v| v['annictId']}
      @renderer.message = annict.episodes(ids.join(',')).to_h {|v| [v['title'], []]}
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      UserTagInitializeWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/lemmy/communities' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.lemmy?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      @renderer.message = sns.account.lemmy&.communities || {}
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
        tags.merge(sns.account.field_tags)
        tags.merge(sns.account.bio_tags)
      end
      @renderer.message = tags.map {|t| hash_tag_class.get(tag: t).to_h}.deep_compact
      return @renderer.to_s
    end

    post '/feed/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      FeedUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/admin/handler/list' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      @renderer.message = Handler.all.map do |handler|
        {name: handler.underscore, disable: config.disable?(handler)}
      end
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/admin/handler/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      config.update_file(handler: {params[:handler] => {disable: params[:flag]}})
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      Sidekiq.set_schedule('puma_daemon_restart', {
        at: config['/puma/restart/seconds'].seconds.after,
        class: 'Mulukhiya::PumaDaemonRestartWorker',
      })
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    CustomAPI.all do |api|
      get api.path do
        @renderer = api.create_renderer(params)
        return @renderer.to_s
      rescue => e
        e.log
        @renderer.status = e.status
        @renderer.message = {error: e.message}
        return @renderer.to_s
      end
    end

    def token
      return params[:token].decrypt
    rescue
      return params[:token]
    end

    def self.default_type
      return 'application/json; charset=UTF-8'
    end
  end
end
