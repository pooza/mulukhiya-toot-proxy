module Mulukhiya
  module Misskey
    class AccessToken < Sequel::Model(:access_token)
      many_to_one :account, key: :userId
    end
  end
end
