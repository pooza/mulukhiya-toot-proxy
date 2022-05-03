module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      include Package
      include AccessTokenMethods
      include SNSMethods
      many_to_one :account, key: :user_id
      many_to_one :application, key: :app_id

      def scopes
        matches = values[:scopes].match(/{(.*?)}/)[1]
        return matches.split(',').to_set if matches
        raise Ginseng::GatewayError, "Invalid scopes '#{values[:scopes]}'"
      rescue => e
        e.log
        return []
      end

      alias to_s token

      def self.get(key)
        return first(key)
      end
    end
  end
end
