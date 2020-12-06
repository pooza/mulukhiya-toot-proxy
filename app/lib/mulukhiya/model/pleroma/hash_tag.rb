module Mulukhiya
  module Pleroma
    class HashTag
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def uri
        @uri ||= Environment.sns_class.new.create_uri("/tag/#{name}")
        return @uri
      end

      def feed_uri
        @feed_uri ||= Environment.sns_class.new.create_uri("/mulukhiya/feed/tag/#{name}")
        return @feed_uri
      end

      def to_h
        return {
          name: name.to_hashtag_base,
          tag: name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        }
      end

      def create_feed(params)
        return [] unless Postgres.config?
        params[:tag] = name
        return Postgres.instance.execute('tag_timeline', params)
      end

      def self.get(key)
        return HashTag.new(key[:tag])
      end
    end
  end
end
