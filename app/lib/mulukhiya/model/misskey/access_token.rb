module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      many_to_one :account, key: :userId
      many_to_one :application, key: :appId

      def scopes
        return application.permission
      end
    end
  end
end
