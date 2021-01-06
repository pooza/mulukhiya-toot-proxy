module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      include Package
      include AccessTokenMethods
      include SNSMethods
      many_to_one :account, key: :userId
      many_to_one :application, key: :appId

      def valid?
        return false if to_s.empty?
        return false unless account
        return true unless application
        return application.name == Package.name
      end

      def to_s
        return values[:hash]
      end

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

      def scopes
        return application.scopes if application
        return nil unless matches = permission.match(/{(.*?)}/)[1]
        return matches.split(',')
      end

      def self.get(key)
        return AccessToken.first(hash: key[:token]) if key.key?(:token)
      end
    end
  end
end
