module Mulukhiya
  module Pleroma
    class Account < Sequel::Model(:users)
      attr_accessor :token

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:username] = username
          @hash[:display_name] = display_name
          @hash[:url] = uri.to_s
          @hash.delete(:password_hash)
          @hash.delete(:keys)
          @hash.delete(:magic_key)
          @hash.compact!
        end
        return @hash
      end

      def acct
        unless @acct
          @acct = Acct.new("@#{nickname}")
          @acct.host ||= Environment.domain_name
        end
        return @acct
      end

      def username
        return acct.username
      end

      alias display_name name

      def uri
        @uri ||= Ginseng::URI.parse(ap_id)
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
        rows = Postgres.instance.exec('recent_status', {actor: ap_id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_toot recent_status

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
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(nickname: acct.to_s.sub(/^@/, ''))
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return AccessToken.first(token: key[:token]).account
        end
        return Account.first(key)
      end
    end
  end
end
