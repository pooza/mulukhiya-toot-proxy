module Mulukhiya
  module Misskey
    class HashTag < Sequel::Model(:hashtag)
      include Package
      include HashTagMethods
      include SNSMethods
      attr_writer :raw_name

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            tag: raw_name.to_hashtag,
            url: uri.to_s,
            feed_url: feed_uri.to_s,
          )
          @hash.delete(:mentionedUserIds)
          @hash.delete(:mentionedLocalUserIds)
          @hash.delete(:mentionedRemoteUserIds)
          @hash.deep_compact!
        end
        return @hash
      end

      def self.get(key)
        if key.key?(:tag)
          record = first(name: key[:tag].downcase)
          record.raw_name = key[:tag]
          return record
        end
        return first(key)
      end
    end
  end
end
