module Mulukhiya
  module Mastodon
    class AccessToken < Sequel::Model(:oauth_access_tokens)
      many_to_one :account, key: :resource_owner_id
      many_to_one :application, key: :application_id

      def valid?
        return expires_in.nil? && revoked_at.nil? && application.name == Package.name
      end

      def webhook_digest
        return Webhook.create_digest(Config.instance['/mastodon/url'], token)
      end

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end
    end
  end
end
