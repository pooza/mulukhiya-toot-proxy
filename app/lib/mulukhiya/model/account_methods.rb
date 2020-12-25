require 'time'

module Mulukhiya
  module AccountMethods
    def user_config
      @user_config ||= UserConfig.new(id)
      return @user_config
    end

    def acct
      @acct ||= Acct.new("@#{username}@#{host}")
      return @acct
    end

    def service
      unless @service
        @service = Environment.sns_class.new
        @service.token = token
      end
      return @service
    end

    def webhook
      return Webhook.new(user_config)
    rescue => e
      logger.error(error: e)
      return nil
    end

    def growi
      unless @growi
        raise Ginseng::ConfigError, '/growi/url undefined' unless user_config['/growi/url']
        raise Ginseng::ConfigError, '/growi/token undefined' unless user_config['/growi/token']
        default_prefix = File.join('/', Package.short_name, 'user', username)
        @growi = GrowiClipper.new(
          uri: user_config['/growi/url'],
          token: user_config['/growi/token'],
          prefix: user_config['/growi/prefix'] || default_prefix,
        )
      end
      return @growi
    rescue => e
      logger.error(error: e, acct: acct.to_s)
      return nil
    end

    def dropbox
      @dropbox ||= DropboxClipper.create(account_id: id)
      return @dropbox
    rescue => e
      logger.error(error: e)
      return nil
    end

    def annict
      return nil unless user_config['/annict/token'].present?
      @annict ||= AnnictService.new(user_config['/annict/token'])
      return @annict
    end

    def featured_tag_bases
      return []
    end

    def notify_verbose?
      return user_config['/notify/verbose'] == true
    end

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return user_config["/handler/#{handler.underscore}/disable"] == true
    rescue Ginseng::ConfigError, NameError
      return false
    end

    def tags
      return user_config['/tagging/user_tags'] || []
    end

    def disabled_tags
      tags = TagContainer.new
      dic_cache = TaggingDictionary.new.load_cache
      (user_config['/tagging/tags/disabled'] || []).each do |tag|
        tags.push(tag)
        tags.concat(dic_cache[tag][:words])
      end
      return tags.to_a
    rescue => e
      Skack.broadcast(e)
    end
  end
end
