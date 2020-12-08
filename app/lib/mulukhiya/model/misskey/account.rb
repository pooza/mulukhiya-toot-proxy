module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      include AccountMethods

      alias display_name name

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:url] = uri.to_s
          @hash[:display_name] = acct.to_s if @hash[:display_name].empty?
          @hash[:is_admin] = admin?
          @hash[:is_moderator] = moderator?
          @hash.delete(:token)
          @hash.deep_compact!
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
        note = notes&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_note recent_status

      alias admin? isAdmin

      alias moderator? isModerator

      alias service? isBot

      alias bot? isBot

      alias locked? isLocked

      def featured_tag_bases
        return []
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, host: acct.domain)
        elsif key.key?(:token)
          return nil if key[:token].nil?
          return first(key) || AccessToken.first(hash: key[:token]).account
        end
        return first(key)
      end
    end
  end
end
