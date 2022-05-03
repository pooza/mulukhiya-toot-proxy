module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      include Package
      include AccessTokenMethods
      include SNSMethods
      many_to_one :account, key: :userId
      many_to_one :application, key: :appId

      def to_s
        return values[:hash]
      end

      def scopes
        return application.scopes if application
        matches = permission.match(/{(.*?)}/)[1]
        return matches.split(',').to_set if matches
        raise Ginseng::GatewayError, "Invalid scopes '#{permission}'"
      end

      def self.get(key)
        case key
        in {token: token}
          return first(hash: token)
        else
          return first(key)
        end
      end
    end
  end
end
