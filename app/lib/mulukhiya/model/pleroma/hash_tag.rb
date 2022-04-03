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

      def to_h
        return {
          name: name.to_hashtag_base,
          tag: raw_name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        }
      end

      def self.featured_tags
        return TagContainer.new
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          record = (new(name: tag) rescue new(name: tag.downcase))
          record ||= new(name: tag.downcase)
          return nil unless record
          record.raw_name = tag
          return record
        else
          return first(key)
        end
      end
    end
  end
end
