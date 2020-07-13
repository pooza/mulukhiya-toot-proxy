module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      include AccountMethods

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
