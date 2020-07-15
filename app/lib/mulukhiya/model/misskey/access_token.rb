module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      many_to_one :account, key: :userId
      many_to_one :application, key: :appId

      def valid?
        return false unless to_s.present?
        return false unless account
        return application.name == Package.name
      end

      def webhook_digest
        return Webhook.create_digest(Environment.sns_class.new.uri, to_s)
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
        matches = application.permission.match(/{(.*?)}/)[1]
        return matches.split(',') if matches
        return Ginseng::GatewayError, "Invalid scopes '#{application.permission}'"
      rescue => e
        Logger.new.error(e)
        return []
      end
    end
  end
end
