module Mulukhiya
  module HashTagMethods
    def uri
      @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
      return @uri
    end

    def feed_uri
      @feed_uri ||= Environment.sns_class.new.create_uri("/mulukhiya/feed/tag/#{name}")
      return @feed_uri
    end

    def create_feed(params)
      return [] unless Postgres.config?
      params[:tag] = name
      return Postgres.instance.execute('tag_timeline', params)
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def featured_tag_bases
        return Postgres.instance.execute('featured_tags').map {|v| v['tag'].to_hashtag_base}
      end

      def field_tag_bases
        return Postgres.instance.execute('field_tags').map {|v| v['tag'].to_hashtag_base}
      end
    end
  end
end
