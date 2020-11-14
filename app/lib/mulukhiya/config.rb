module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler)
      handler = Handler.create(handler) unless handler.is_a?(Handler)
      return self["/handler/#{handler.underscore_name}/disable"] == true
    rescue Ginseng::ConfigError, NameError
      return false
    end

    def schema
      unless @schema
        @schema = Config.load_file('schema/base')
        @schema['properties'][controller] = Config.load_file("schema/#{controller}")
        @schema['required'].push(controller)
        @schema['required'].push(dbms)
        @schema['required'].push('controller') unless controller == 'mastodon'
        @schema['properties']['handler'] = handlers
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
          handlers[handler.underscore_name] ||= handler.schema
        end
      end
      return handlers
    end

    def controller
      return Environment.controller_name
    end

    def dbms
      return Environment.dbms_name
    end
  end
end
