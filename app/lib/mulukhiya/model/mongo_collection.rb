module Mulukhiya
  class MongoCollection
    include Package
    include SNSMethods
    attr_reader :id

    def initialize(id)
      @id = id.to_s
    end

    def values
      @values ||= collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
      return @values
    end

    alias to_h values

    def aggregate(name, params = {})
      template = Template.new(File.join(Environment.dir, 'app/query/meisskey', "#{name}.yaml.erb"))
      template.params = params
      return collection.aggregate(YAML.parse(template.to_s))
    end

    private

    def method_missing(method, *args)
      return values[method.to_s] if args.empty?
      return super
    end

    def respond_to_missing?(method, *args)
      return args.empty? if args.is_a?(Array)
      return super
    end

    def collection_name
      return self.class.to_s.underscore.to_sym
    end

    def collection
      return Mongo.instance.db[collection_name]
    end
  end
end
