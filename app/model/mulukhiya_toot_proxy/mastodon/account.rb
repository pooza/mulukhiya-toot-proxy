module MulukhiyaTootProxy
  module Mastodon
    class Account < Sequel::Model(:accounts)
      attr_accessor :token

      def initialize
        super
        @logger = Logger.new
      end

      alias to_h values

      def config
        @config ||= UserConfigStorage.new[id]
        return @config
      rescue => e
        @logger.error(e)
        return {}
      end

      def webhook
        @webhook ||= Webhook.new(config)
        raise "Invalid webhook #{config.to_json}" unless @webhook.exist?
        return @webhook
      rescue => e
        @logger.error(e)
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
        @logger.error(e)
        return nil
      end

      def growi
        @growi ||= GrowiClipper.create(account_id: id)
        return @growi
      rescue => e
        @logger.error(e)
        return nil
      end

      def dropbox
        @dropbox ||= DropboxClipper.create(account_id: id)
        return @dropbox
      rescue => e
        @logger.error(e)
        return nil
      end

      def params
        @params ||= Postgres.instance.execute('account', {id: id}).first
        return @params
      end

      def recent_toot
        rows = Postgres.instance.execute('recent_toot', {id: id})
        return rows.present? ? Toot[rows.first['id'].to_i] : nil
      end

      def admin?
        return params[:admin]
      end

      def moderator?
        return params[:moderator]
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

      def self.get(key)
        if token = key[:token]
          account = Postgres.instance.execute('token_owner', {token: token})&.first
          account = Account[account[:id]]
          account.token = token
          return account
        elsif key[:acct]
          username, domain = key[:acct].sub(/^@/, '').split('@')
          return Account.first(username: username, domain: domain)
        end
        raise Ginseng::NotFoundError, "Account '#{key.to_json}' not found" unless @params.present?
      end
    end
  end
end
