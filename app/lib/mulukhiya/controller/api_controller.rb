module Mulukhiya
  class APIController < Controller
    get '/about' do
      sns.token ||= sns.default_token
      @renderer.message = {package: config.raw.dig('application', 'package')}
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
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      ProgramUpdateWorker.perform_async
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
      params[:page] = params[:page]&.to_i || 1
      params.delete(:q) unless params[:q].present?
      params.delete(:q) unless sns.account
      errors = PagerContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      elsif controller_class.media_catalog?
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

    post '/media/catalog/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account&.operator?
      MediaCatalogUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/status' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.account_timeline?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      params[:limit] ||= config['/webui/status/timeline/limit']
      params[:page] = params[:page]&.to_i || 1
      params.delete(:q) unless params[:q].present?
      errors = PagerContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
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
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.account_timeline?
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless status = status_class[params[:id]]
      raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
      @renderer.message = status.to_h
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
      errors = StatusTagContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        status = status_class[params[:id]]
        raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
        tags = TagContainer.scan(status.parser.footer).push(params[:tag])
        @renderer.message = sns.update_status(
          params[:id],
          [status.parser.body, tags.map(&:to_hashtag).join(' ')].join("\n"),
        )
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
      errors = StatusTagContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors:}
      else
        status = status_class[params[:id]]
        raise Ginseng::AuthError, 'Unauthorized' unless status.updatable_by?(sns.account)
        tags = TagContainer.scan(status.parser.footer).delete(tag.name)
        @renderer.message = sns.update_status(
          params[:id],
          [status.parser.body, tags.map(&:to_hashtag).join(' ')].join("\n"),
        )
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
