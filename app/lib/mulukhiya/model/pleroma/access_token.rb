module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      include Package
      include AccessTokenMethods
      many_to_one :account, key: :user_id
      many_to_one :application, key: :app_id

      def valid?
        return false if to_s.empty?
        return false unless account
        return application.name == Package.name
      end

      def scopes
        matches = values[:scopes].match(/{(.*?)}/)[1]
        return matches.split(',') if matches
        return Ginseng::GatewayError, "Invalid scopes '#{values[:scopes]}'"
      rescue => e
        logger.error(error: e)
        return []
      end

      alias to_s token

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            digest: webhook_digest,
            token: to_s,
            account: account,
            scopes: scopes,
          )
          @hash.deep_compact!
        end
        return @hash
      end

      def self.get(key)
        return AccessToken.first(key)
      end
    end
  end
end
