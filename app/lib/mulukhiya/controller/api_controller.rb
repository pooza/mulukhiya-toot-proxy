module Mulukhiya
  class APIController < Controller
    get '/about' do
      @sns.token ||= @sns.default_token
      @renderer.message = {package: config.raw.dig('application', 'package')}
      return @renderer.to_s
    end

    get '/health' do
      @sns.token ||= @sns.default_token
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/config' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account
      @sns.account.user_config.token = token
      @renderer.message = {
        account: @sns.account.to_h,
        config: @sns.account.user_config.to_h,
        webhook: {url: @sns.account.webhook.uri.to_s},
        filters: @sns.filters&.parsed_response,
        token: @sns.access_token.to_h.except(:account),
        visibility_names: parser_class.visibility_names,
      }
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/config/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account
      Handler.create('user_config_command').handle_toot(params, {sns: @sns})
      @renderer.message = {config: @sns.account.user_config.to_h}
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/filter/add' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.filter?
      Handler.create('filter_command').handle_toot(params, {sns: @sns})
      @renderer.message = {filters: @sns.filters}
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/mastodon/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.mastodon_type?
      errors = MastodonAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors: errors}
      else
        response = @sns.auth(params[:code], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = @renderer.message['access_token'].encrypt
      end
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/misskey/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless Environment.misskey_type?
      errors = MisskeyAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors: errors}
      else
        response = @sns.auth(params[:code], params[:type])
        token = @sns.create_access_token(response.parsed_response['accessToken'], params[:type])
        @renderer.message = response.parsed_response
        @renderer.message['access_token_crypt'] = token.encrypt
      end
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/program' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      @sns.token ||= @sns.default_token
      @renderer.message = Program.instance.data
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/program/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.livecure?
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      ProgramUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/media' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.media_catalog?
      @sns.token ||= @sns.default_token
      params[:page] = params[:page]&.to_i || 1
      errors = PagerContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors: errors}
      elsif controller_class.media_catalog?
        @renderer.message = attachment_class.catalog(params)
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/file/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      MediaCleaningWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/media/metadata/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      MediaMetadataStorage.new.clear
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/annict/auth' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.annict?
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors: errors}
      else
        response = AnnictService.new.auth(params[:code])
        @sns.account.user_config.update(annict: {token: response['access_token']})
        @sns.account.annict.updated_at = Time.now
        @renderer.status = response.code
        @renderer.message = {config: @sns.account.user_config.to_h}
      end
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/announcement/update' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.announcement?
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      AnnouncementWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/tagging/favorites' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.favorite_tags?
      @sns.token ||= @sns.default_token
      @renderer.message = hash_tag_class.favorites
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/dic/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      TaggingDictionaryUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/tagging/tag/search' do
      dic = {}
      errors = TagSearchContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = {errors: errors}
      else
        TaggingDictionary.new.cache.each do |entry|
          word = entry.shift
          next unless params[:q].match?(entry.first[:regexp])
          dic[word] = entry.first
          dic[word][:word] = word
          dic[word][:short] = TaggingDictionary.short?(word)
          dic[word][:words].unshift(word)
          dic[word][:tags] = TagContainer.new(dic.dig(word, :words)).create_tags
        rescue => e
          logger.error(error: e, entry: entry)
        end
        @renderer.message = dic
      end
      return @renderer.to_s
    end

    post '/tagging/usertag/clear' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      UserTagInitializeWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/feed/list' do
      tags = TagContainer.new
      tags.merge(DefaultTagHandler.tags)
      tags.merge(MediaTagHandler.all.values)
      if @sns.account
        tags.merge(@sns.account.featured_tags)
        tags.merge(@sns.account.field_tags)
        tags.merge(@sns.account.bio_tags)
      end
      @renderer.message = tags.map {|t| hash_tag_class.get(tag: t).to_h}.deep_compact
      return @renderer.to_s
    end

    post '/feed/update' do
      raise Ginseng::AuthError, 'Unauthorized' unless @sns.account&.operator?
      FeedUpdateWorker.perform_async
      return @renderer.to_s
    rescue => e
      logger.error(error: e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    CustomAPI.all do |api|
      get api.path do
        @renderer = api.create_renderer(params)
        return @renderer.to_s
      rescue => e
        logger.error(error: e)
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
