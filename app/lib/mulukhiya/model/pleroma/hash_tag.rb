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

      def self.featured_tags
        return TagContainer.new
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          return nil unless record = new(tag.downcase)
          record.raw_name = tag
          return record
        else
          return first(key)
        end
      end
    end
  end
end
