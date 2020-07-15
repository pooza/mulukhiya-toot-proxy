module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      many_to_one :account, key: :userId
      many_to_one :application, key: :appId

      def valid?
        return account && token && application.name == Package.name
      end

      def webhook_digest
        return Webhook.create_digest(Config.instance['/misskey/url'], to_s)
      end

      def to_s
        return values[:hash]
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash.merge!(
            digest: webhook_digest,
            token: to_s,
            account: account,
            scopes: scopes,
          )
          @hash.compact!
        end
        return @hash
      end

      def scopes
        return application.permission
      end
    end
  end
end
