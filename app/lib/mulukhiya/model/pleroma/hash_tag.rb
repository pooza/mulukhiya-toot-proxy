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
          feed_url: feed_uri.to_s,
          is_default: default?,
          is_deletable: deletable?,
          name: name.to_hashtag_base,
          tag: raw_name.to_hashtag,
          url: uri.to_s,
        }
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          return nil unless record = new(tag.downcase)
          record.raw_name = tag
          return record
        end
      end
    end
  end
end
