module Mulukhiya
  module Mastodon
    class HashTag < Sequel::Model(:tags)
      def uri
        @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
        return @uri
      end

      def feed_uri
        @feed_uri ||= Environment.sns_class.new.create_uri("/mulukhiya/feed/tag/#{name}")
        return @feed_uri
      end

      def to_h
        @hash ||= values.clone.merge(
          url: uri.to_s,
          feed_uri: feed_uri.to_s,
        )
        return @hash
      end

      def create_feed(params)
        return [] unless Postgres.config?
        params[:tag] = name
        return Postgres.instance.execute('tag_timeline', params)
      end

      def self.get(key)
        return HashTag.first(name: key[:tag]) if key.key?(:tag)
        return HashTag.first(key)
      end
    end
  end
end
