module Mulukhiya
  module Pleroma
    class Account < Sequel::Model(:users)
      attr_accessor :token

      one_to_one :user

      def to_h
        unless @hash
          @hash = values.clone
          @hash.delete(:password_hash)
          @hash.delete(:keys)
          @hash.delete(:magic_key)
          @hash.compact!
        end
        return @hash
      end

      def acct
        @acct ||= Acct.new("@#{username}@#{domain || Environment.domain_name}")
        return @acct
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

      def recent_toot
      end

      alias recent_status recent_toot

      alias admin? is_admin

      alias moderator? is_moderator

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      alias locked? locked

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
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return AccessToken.first(token: key[:token]).account
        end
        return Account.first(key)
      end
    end
  end
end
