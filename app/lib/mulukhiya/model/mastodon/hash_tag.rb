module Mulukhiya
  module Mastodon
    class HashTag < Sequel::Model(:tags)
      include Package
      include HashTagMethods
      include SNSMethods
      attr_writer :raw_name

      def listable?
        return listable != false
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          return unless record = (first(name: tag) || first(name: tag.downcase))
          record.raw_name = tag
          return record
        else
          return first(key)
        end
      end
    end
  end
end
