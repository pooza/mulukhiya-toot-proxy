module Mulukhiya
  module Misskey
    class HashTag < Sequel::Model(:hashtag)
      include Package
      include HashTagMethods
      include SNSMethods

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            tag: name.to_hashtag,
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
        return HashTag.first(name: key[:tag].downcase) if key.key?(:tag)
        return HashTag.first(key.downcase)
      end
    end
  end
end
