module Mulukhiya
  module Dolphin
    class Account < Sequel::Model(:user)
      def acct
        @acct ||= Acct.new("@#{username}@#{host || DolphinService.new.uri.host}")
        return @acct
      end

      def uri
        unless @uri
          if host
            @uri = NoteURI.parse("https://#{host}")
          else
            @uri = NoteURI.parse(Config.instance['/dolphin/url'])
          end
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def to_h
        v = values.clone
        v[:url] = uri.to_s
        v.delete(:token)
        v.compact!
        return v
      end

      def logger
        @logger ||= Logger.new
        return @logger
      end

      def config
        return UserConfigStorage.new[id]
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
        rows = Postgres.instance.execute('recent_note', {id: id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_status recent_note

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
        return true if config['/handler/default/disable']
        return false
      end

      def tags
        return config['/tags'] || []
      end

      def self.get(key)
        return Account.first(token: key[:token]) if key[:token]
        if key[:acct]
          acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, host: acct.host)
        end
        raise Ginseng::NotFoundError, "Account '#{key.to_json}' not found"
      end
    end
  end
end
