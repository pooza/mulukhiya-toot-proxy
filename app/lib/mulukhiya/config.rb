module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return self["/handler/#{handler.underscore}/disable"] == true rescue false
    end

    def schema
      unless @schema
        @schema = self.class.load_file('schema/base').deep_symbolize_keys
        @schema[:properties].merge!(
          controller_name.to_sym => self.class.load_file("schema/controller/#{controller_name}"),
          :handler => handlers,
        )
        @schema[:required].push('controller') unless controller_name == 'mastodon'
        @schema[:required].concat([controller_name, dbms_name])
        @schema.deep_stringify_keys!
      end
      return @schema
    end

    def self.load_file(name)
      name += '.yaml' if File.extname(name).empty?
      return YAML.load_file(File.join(Environment.dir, 'config', name))
    end

    private

    def handlers
      handlers = {}
      Event.all do |event|
        event.handlers do |handler|
          handlers[handler.underscore] = handler.schema
        end
      end
      return {properties: handlers.deep_symbolize_keys}
    end

    def controller_name
      return Environment.controller_name
    end

    def dbms_name
      return Environment.dbms_name
    end
  end
end
