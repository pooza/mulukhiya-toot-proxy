module Mulukhiya
  module Misskey
    class HashTag < Sequel::Model(:hashtag)
      include Package
      include HashTagMethods
      include SNSMethods

      attr_writer :raw_name

      def to_h
        return super.except(
          :mentionedUserIds,
          :mentionedLocalUserIds,
          :mentionedRemoteUserIds,
        )
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          return nil unless record = first(name: tag) || first(name: tag.downcase)
          record.raw_name = key[:tag]
          return record
        else
          return first(key)
        end
      end
    end
  end
end
