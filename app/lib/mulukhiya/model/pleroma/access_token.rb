module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      many_to_one :account, key: :user_id
      many_to_one :application, key: :app_id

      def valid?
        return false if to_s.empty?
        return false unless account
        return application.name == Package.name
      end

      def webhook_digest
        return Webhook.create_digest(Environment.sns_class.new.uri, to_s)
      end

      def scopes
        matches = values[:scopes].match(/{(.*?)}/)[1]
        return matches.split(',') if matches
        return Ginseng::GatewayError, "Invalid scopes '#{values[:scopes]}'"
      rescue => e
        Logger.new.error(error: e)
        return []
      end

      alias to_s token

      def to_h
        unless @hash
          @hash = values.deep_compact
          @hash.merge!(
            digest: webhook_digest,
            token: to_s,
            account: account,
            scopes: scopes,
          )
        end
        return @hash
      end
    end
  end
end
