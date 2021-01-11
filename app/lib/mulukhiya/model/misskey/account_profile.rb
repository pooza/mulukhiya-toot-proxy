module Mulukhiya
  module Misskey
    class AccountProfile < Sequel::Model(:user_profile)
      include Package
      include SNSMethods
    end
  end
end
