module Mulukhiya
  module Meisskey
    class Application
      attr_reader :id

      def initialize(id)
        @id = id.to_s
        @logger = Logger.new
      end

      def values
        @values ||= Application.collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
        return @values
      end

      def permission
        return values['permission'].join(' ')
      end

      def self.[](id)
        return Application.new(id)
      end

      def self.collection
        return Mongo.instance.db[:apps]
      end
    end
  end
end
