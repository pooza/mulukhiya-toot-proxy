module Mulukhiya
  module Mastodon
    class AccessToken < Sequel::Model(:oauth_access_tokens)
      include AccessTokenMethods
      many_to_one :user, key: :resource_owner_id
      many_to_one :application

      def valid?
        return false if to_s.empty?
        return false unless user.account
        return false if expires_in.present?
        return false if revoked_at.present?
        return application.name == Package.name
      end

      alias to_s token

      def scopes
        return values[:scopes].split(/\s+/)
      end

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            digest: webhook_digest,
            token: to_s,
            account: user.account,
            scopes: scopes,
          )
          @hash.deep_compact!
        end
        return @hash
      end
    end
  end
end
