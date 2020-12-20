module Mulukhiya
  module Pleroma
    class Account < Sequel::Model(:users)
      include Package
      include AccountMethods
      attr_accessor :token

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            username: username,
            display_name: display_name,
            is_admin: admin?,
            is_moderator: moderator?,
            url: uri.to_s,
          )
          @hash[:display_name] = acct.to_s if @hash[:display_name].empty?
          @hash.delete(:password_hash)
          @hash.delete(:keys)
          @hash.delete(:magic_key)
          @hash.deep_compact!
        end
        return @hash
      end

      def acct
        unless @acct
          @acct = Acct.new("@#{nickname}")
          @acct = Acct.new("@#{nickname}@#{Environment.domain_name}") unless @acct.host
        end
        return @acct
      end

      def username
        return acct.username
      end

      alias display_name name

      def host
        return acct.host
      end

      alias domain host

      def uri
        @uri ||= Ginseng::URI.parse(ap_id)
        return @uri
      end

      def recent_status
        notes = service.statuses(account_id: id)
        note = notes&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_toot recent_status

      alias admin? is_admin

      alias moderator? is_moderator

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      def locked?
        return false
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          nickname = acct.username if acct.local?
          nickname ||= acct.to_s.sub(/^@/, '')
          return first(nickname: nickname)
        elsif key.key?(:token)
          return nil if key[:token].nil?
          account = AccessToken.first(token: key[:token]).account
          account.token = key[:token]
          return account
        end
        return first(key)
      end
    end
  end
end
