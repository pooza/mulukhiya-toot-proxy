module Mulukhiya
  module Mastodon
    class Account < Sequel::Model(:accounts)
      attr_accessor :token

      one_to_one :user

      def to_h
        unless @hash
          @hash = values.clone
          @hash.delete(:private_key)
          @hash.delete(:public_key)
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
        rows = Postgres.instance.exec('recent_toot', {id: id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_status recent_toot

      def admin?
        return user.admin
      end

      def moderator?
        return user.moderator
      end

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
        if key.key?(:token)
          return nil if key[:token].nil?
          account = Postgres.instance.exec('token_owner', {token: key[:token]})&.first
          account = Account[account[:id]]
          account.token = key[:token]
          return account
        elsif acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, domain: acct.domain)
        end
        return Account.first(key)
      end
    end
  end
end
