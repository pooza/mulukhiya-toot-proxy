module Mulukhiya
  module Mastodon
    class HashTag < Sequel::Model(:tags)
      include Package
      include HashTagMethods
      include SNSMethods
      attr_writer :raw_name

      def to_h
        @hash ||= values.deep_symbolize_keys.merge(
          tag: raw_name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        )
        @hash.deep_compact!
        return @hash
      end

      def listable?
        return listable != false
      end

      def self.get(key)
        if key.key?(:tag)
          return unless record = first(name: key[:tag].downcase)
          record.raw_name = key[:tag]
          return record
        end
        return first(key)
      end
    end
  end
end
