module Mulukhiya
  module HashTagMethods
    def raw_name
      return @raw_name || name
    end

    def uri
      @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
      return @uri
    end

    def listable?
      return true
    end

    def feed_uri
      @feed_uri ||= Environment.sns_class.new.create_uri("/mulukhiya/feed/tag/#{raw_name}")
      return @feed_uri
    end

    def create_feed(params)
      return [] unless Postgres.config?
      params[:tag] = name
      params[:tag_id] = id rescue nil
      return Postgres.instance.execute('tag_timeline', params)
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def favorites
        return nil
      end
    end
  end
end
