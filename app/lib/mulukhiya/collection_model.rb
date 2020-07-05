require 'mongo'

module Mulukhiya
  class CollectionModel
    attr_reader :id

    def initialize(id)
      @id = id.to_s
      @logger = Logger.new
      @config = Config.instance
    end

    def values
      @values ||= collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
      return @values
    end

    alias to_h values

    private

    def method_missing (method)
      return values[method.to_s]
    end

    def collection_name
      return self.class.to_s.downcase.to_sym
    end

    def collection
      return Mongo.instance.db[collection_name]
    end
  end
end
