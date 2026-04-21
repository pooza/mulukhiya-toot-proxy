module Mulukhiya
  module Misskey
    class SwSubscription < Sequel::Model(:sw_subscription)
      include Package

      many_to_one :account, key: :userId
    end
  end
end
