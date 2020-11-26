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

      def to_h
        return {
          name: name,
          url: uri.to_s,
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
