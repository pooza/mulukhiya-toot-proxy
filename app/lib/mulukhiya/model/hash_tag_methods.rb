module Mulukhiya
  module HashTagMethods
    def uri
      @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
      return @uri
    end

    def listable?
      return true
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
  end
end
