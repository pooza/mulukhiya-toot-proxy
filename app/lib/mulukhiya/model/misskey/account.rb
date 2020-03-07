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
          if host
            @uri = NoteURI.parse("https://#{host}")
          else
            @uri = NoteURI.parse(Config.instance['/misskey/url'])
          end
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
        if key[:acct]
          acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, host: acct.domain)
        end
        return Account.first(key)
      end
    end
  end
end
