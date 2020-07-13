module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      many_to_one :account, key: :user_id

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end
    end
  end
end
