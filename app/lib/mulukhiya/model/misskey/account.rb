module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      def to_h
        unless @hash
          @hash = values.clone
          @hash[:url] = uri.to_s
          @hash.delete(:token)
          @hash.compact!
        end
        return @hash
      end

      def acct
        @acct ||= Acct.new("@#{username}@#{host || Environment.domain_name}")
        return @acct
      end

      def uri
        unless @uri
          @uri = Ginseng::URI.parse("https://#{host}") if host
          @uri ||= Environment.sns_class.new.uri.clone
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def logger
        @logger ||= Logger.new
        return @logger
      end

      def config
        @config ||= UserConfig.new(id)
        return @config
      end

      def webhook
        return Webhook.new(config)
      rescue => e
        logger.error(e)
        return nil
      end

      def growi
        @growi ||= GrowiClipper.create(account_id: id)
        return @growi
      rescue => e
        logger.error(e)
        return nil
      end

      def dropbox
        @dropbox ||= DropboxClipper.create(account_id: id)
        return @dropbox
      rescue => e
        logger.error(e)
        return nil
      end

      def twitter
        unless @twitter
          return nil unless config['/twitter/token']
          return nil unless config['/twitter/secret']
          @twitter = TwitterService.new do |twitter|
            twitter.consumer_key = TwitterService.consumer_key
            twitter.consumer_secret = TwitterService.consumer_secret
            twitter.access_token = config['/twitter/token']
            twitter.access_token_secret = config['/twitter/secret']
          end
        end
        return @twitter
      rescue => e
        logger.error(e)
        return nil
      end

      def recent_status
        notes = MisskeyService.new.notes(account_id: id)
        note = notes.parsed_response&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_note recent_status

      alias admin? isAdmin

      def moderator?
        return false
      end

      alias service? isBot

      alias bot? isBot

      alias locked? isLocked

      def notify_verbose?
        return config['/notify/verbose'] == true
      end

      def disable?(handler_name)
        return true if config["/handler/#{handler_name}/disable"]
        return false
      end

      def tags
        return config['/tags'] || []
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, host: acct.domain)
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return Account.first(key) || AccessToken.first(hash: key[:token]).account
        end
        return Account.first(key)
      end
    end
  end
end
