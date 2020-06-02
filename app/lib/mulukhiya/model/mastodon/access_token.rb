module Mulukhiya
  module Mastodon
    class AccessToken < Sequel::Model(:oauth_access_tokens)
      many_to_one :account, key: :resource_owner_id

      def to_h
        unless @hash
          @hash = values.clone
          @hash.compact!
        end
        return @hash
      end
    end
  end
end
