module Mulukhiya
  module Pleroma
    class HashTag
      include HashTagMethods
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_h
        return {
          name: name.to_hashtag_base,
          tag: name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        }
      end

      def self.featured_tag_base
        return []
      end

      def self.get(key)
        return HashTag.new(key[:tag])
      end
    end
  end
end
