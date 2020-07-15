module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      many_to_one :account, key: :user_id
      many_to_one :application, key: :app_id

      def valid?
        return account && token && application.name == Package.name
      end

      def webhook_digest
        return Webhook.create_digest(Config.instance['/pleroma/url'], token)
      end

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end
    end
  end
end
