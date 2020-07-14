module Mulukhiya
  module Mastodon
    class AccessToken < Sequel::Model(:oauth_access_tokens)
      many_to_one :account, key: :resource_owner_id

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end
    end
  end
end
