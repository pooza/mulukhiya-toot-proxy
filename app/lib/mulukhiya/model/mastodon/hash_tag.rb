module Mulukhiya
  module Mastodon
    class HashTag < Sequel::Model(:tags)
      include Package
      include HashTagMethods
      include SNSMethods

      def to_h
        @hash ||= values.deep_symbolize_keys.merge(
          tag: name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        )
        @hash.deep_compact!
        return @hash
      end

      def self.get(key)
        return HashTag.first(name: key[:tag]) if key.key?(:tag)
        return HashTag.first(key)
      end
    end
  end
end
