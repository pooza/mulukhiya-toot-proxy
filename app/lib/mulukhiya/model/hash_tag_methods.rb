module Mulukhiya
  module HashTagMethods
    def logger
      @logger ||= Logger.new
      return @logger
    end

    def config
      return Config.instance
    end

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
      def logger
        return Logger.new
      end

      def config
        return Config.instance
      end
    end
  end
end
