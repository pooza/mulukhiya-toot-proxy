module Mulukhiya
  module Mastodon
    class User < Sequel::Model(:users)
      many_to_one :account
      many_to_one :role
    end
  end
end
