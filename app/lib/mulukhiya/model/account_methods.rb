module Mulukhiya
  module AccountMethods
    include SNSMethods

    def user_config
      @user_config ||= UserConfig.new(id)
      return @user_config
    end

    def acct
      @acct ||= Acct.new("@#{username}@#{host}")
      return @acct
    end

    def operator?
      return admin? || moderator?
    end

    def service
      unless @service
        @service = sns_class.new
        @service.token = token
        @service.retry_limit = 1
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

    def lemmy
      unless @lemmy
        ['host', 'user', 'password', 'community'].freeze.each do |key|
          raise Ginseng::ConfigError, "/lemmy/#{key} undefined" unless user_config["/lemmy/#{key}"]
        end
        @lemmy = LemmyClipper.new(
          host: user_config['/lemmy/host'],
          user: user_config['/lemmy/user'],
          password: (user_config['/lemmy/password'].decrypt rescue user_config['/lemmy/password']),
          community: user_config['/lemmy/community'],
        )
      end
      return @lemmy
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
      return Set[]
    end

    def field_tag_bases
      return fields.map {|v| v['value']}
          .filter {|v| v.start_with?('#')}
          .map(&:to_hashtag_base).to_set
    rescue => e
      logger.error(error: e, acct: acct.to_s)
      return Set[]
    end

    def bio_tag_bases
      return TagContainer.scan(bio)
    rescue => e
      logger.error(error: e, acct: acct.to_s)
      return Set[]
    end

    def notify_verbose?
      return user_config['/notify/verbose'] == true
    end

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return user_config["/handler/#{handler.underscore}/disable"] == true rescue false
    end

    def user_tag_bases
      return (user_config['/tagging/user_tags'] || []).to_set
    end

    alias tags user_tag_bases

    def disabled_tag_bases
      tags = TagContainer.new
      dic_cache = TaggingDictionary.new.cache
      (user_config['/tagging/tags/disabled'] || []).each do |tag|
        tags.add(tag)
        tags.merge(dic_cache[tag][:words])
      end
      return tags
    rescue => e
      logger.error(error: e, acct: acct.to_s)
    end

    def attachments
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def clear_attachments(params = {})
      raise Ginseng::AuthError, 'Only test users can run it' unless test?
      bar = ProgressBar.create(total: status_delete_limit)
      attachments.first(status_delete_limit).each do |attachment|
        service.delete_attachment(attachment) unless params[:dryrun]
      rescue => e
        logger.error(error: e, acct: acct.to_s)
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def default_scopes
      return controller_class.oauth_scopes(:infobot) if info?
      return controller_class.oauth_scopes
    end

    def status_delete_limit
      return controller_class.status_delete_limit || attachments.count
    end

    def test?
      return account_class.test_account&.id == id
    end

    def info?
      return account_class.info_account&.id == id
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def test_token
        return config['/agent/test/token'].decrypt
      rescue Ginseng::ConfigError
        return nil
      rescue
        return config['/agent/test/token']
      end

      def test_account
        return Environment.account_class.get(token: test_token)
      end

      def info_token
        return config['/agent/info/token'].decrypt
      rescue Ginseng::ConfigError
        return nil
      rescue
        return config['/agent/info/token']
      end

      def info_account
        return Environment.account_class.get(token: info_token)
      end
    end
  end
end
