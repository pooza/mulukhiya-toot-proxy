module Mulukhiya
  module Misskey
    class HashTag < Sequel::Model(:hashtag)
      def uri
        @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
        return @uri
      end

      alias to_h values

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
