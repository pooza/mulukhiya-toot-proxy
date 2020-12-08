module Mulukhiya
  module Pleroma
    class Account < Sequel::Model(:users)
      include AccountMethods
      attr_accessor :token

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:username] = username
          @hash[:display_name] = display_name
          @hash[:display_name] = acct.to_s if @hash[:display_name].empty?
          @hash[:is_admin] = admin?
          @hash[:is_moderator] = moderator?
          @hash[:url] = uri.to_s
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

      def recent_status
        notes = PleromaService.new.statuses(account_id: id)
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

      def featured_tag_bases
        return []
      end

      def self.get(key)
        if acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(nickname: acct.to_s.sub(/^@/, ''))
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
