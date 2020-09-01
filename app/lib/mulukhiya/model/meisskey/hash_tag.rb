module Mulukhiya
  module Meisskey
    class HashTag < CollectionModel
      def name
        return values['tag']
      end

      def uri
        @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
        return @uri
      end

      def self.[](id)
        return HashTag.new(id)
      end

      def self.get(key)
        return nil if key[:tag].nil?
        tag = collection.find(tag: key[:tag]).first
        return HashTag.new(tag['_id'])
      end

      def self.first(key)
        return get(key)
      end

      def self.collection
        return Mongo.instance.db[:hashtags]
      end

      private

      def collection_name
        return :hashtags
      end
    end
  end
end
