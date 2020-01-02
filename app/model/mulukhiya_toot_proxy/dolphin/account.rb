module MulukhiyaTootProxy
  module Dolphin
    class Account < Sequel::Model(:user)
      attr_accessor :token

      alias to_h values

      def logger
        @logger = Logger.new
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

      def recent_note
        # rows = Postgres.instance.execute('recent_toot', {id: id})
        # return rows.present? ? Environment.status_class[rows.first['id']] : nil
      end

      alias recent_status recent_note

      def admin?
        return isAdmin
      end

      def moderator?
        return false
      end

      def service?
        return isBot
      end

      alias bot? service?

      def locked?
        return isLocked
      end

      def disable?(handler_name)
        return true if config["/handler/#{handler_name}/disable"]
        return true if config['/handler/default/disable']
        return false
      end

      def self.get(key)
        return Account.first(token: key[:token]) if key[:token]
        raise Ginseng::NotFoundError, "Account '#{key.to_json}' not found" unless @params.present?
      end
    end
  end
end
