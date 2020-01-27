module Mulukhiya
  module Mastodon
    class Account < Sequel::Model(:accounts)
      attr_accessor :token

      one_to_one :user

      alias to_h values

      def acct
        @acct ||= Acct.new("@#{username}@#{domain || MastodonService.new.uri.host}")
        return @acct
      end

      def logger
        @logger ||= Logger.new
        return @logger
      end

      def config
        @config ||= UserConfigStorage.new[id]
        return @config
      rescue => e
        logger.error(e)
        return {}
      end

      def webhook
        @webhook ||= Webhook.new(config)
        raise "Invalid webhook #{config.to_json}" unless @webhook.exist?
        return @webhook
      rescue => e
        logger.error(e)
        return nil
      end

      def slack
        unless @slack
          uri = Ginseng::URI.parse(config['/slack/webhook'])
          raise "Invalid URI #{config['/slack/webhook']}" unless uri&.absolute?
          @slack = Slack.new(uri)
        end
        return @slack
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

      def recent_toot
        rows = Postgres.instance.execute('recent_toot', {id: id})
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

      def locked?
        return prams[:locked]
      end

      def disable?(handler_name)
        return true if config["/handler/#{handler_name}/disable"]
        return true if config['/handler/default/disable']
        return false
      end

      def tags
        return config['/tags'] || []
      end

      def self.get(key)
        if token = key[:token]
          account = Postgres.instance.execute('token_owner', {token: token})&.first
          account = Account[account[:id]]
          account.token = token
          return account
        elsif key[:acct]
          acct = key[:acct]
          acct = Acct.new(acct) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, domain: acct.host)
        end
        raise Ginseng::NotFoundError, "Account '#{key.to_json}' not found"
      end
    end
  end
end
