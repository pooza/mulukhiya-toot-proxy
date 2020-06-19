module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      many_to_one :account, key: :user_id
    end
  end
end
