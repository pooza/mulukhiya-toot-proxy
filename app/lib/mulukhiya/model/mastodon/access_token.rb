module Mulukhiya
  module Mastodon
    class AccessToken < Sequel::Model(:oauth_access_tokens)
      include Package
      include AccessTokenMethods
      include SNSMethods

      many_to_one :user, key: :resource_owner_id
      many_to_one :application

      # 空白だけのトークンも無効とする（AccessTokenMethods#valid? と同じ理由、#4487）。
      def valid?
        return false if to_s.blank?
        return false unless user.account
        return false if expires_in.present?
        return false if revoked_at.present?
        return true
      end

      alias to_s token

      def scopes
        return values[:scopes].split(/\s+/).to_set
      end

      def account
        return user.account
      end

      def self.get(key)
        return first(key)
      end
    end
  end
end
