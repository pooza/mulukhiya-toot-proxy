module Mulukhiya
  module Pleroma
    class HashTag
      include Package
      include HashTagMethods
      include SNSMethods
      attr_reader :name
      attr_writer :raw_name

      def initialize(name)
        @name = name
      end

      def raw_name
        return @raw_name || name
      end

      def to_h
        return {
          name: name.to_hashtag_base,
          tag: raw_name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        }
      end

      def self.featured_tag_bases
        return []
      end

      def self.get(key)
        return nil unless record = HashTag.new(key[:tag].downcase)
        record.raw_name = key[:tag]
        return record
      end
    end
  end
end
