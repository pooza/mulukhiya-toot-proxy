require 'json-schema'

module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler_name)
      return self["/handler/#{handler_name}/disable"] == true
    rescue Ginseng::ConfigError
      return false
    end

    def errors
      return JSON::Validator.fully_validate(schema, raw['local'])
    end

    def self.load_file(name)
      name += '.yaml' unless File.extname(name).present?
      return YAML.load_file(File.join(Environment.dir, 'config', name))
    end

    def schema
      unless @schema
        @schema = Config.load_file('schema/base')
        @schema['properties'][controller] = Config.load_file("schema/#{controller}")
        @schema['required'].push(controller)
        @schema['required'].push('controller') unless controller == 'mastodon'
        @schema['properties']['handler'] = handlers
      end
      return @schema
    end

    private

    def handlers
      handlers = {}
      Environment.controller_class.events.each do |event|
        Handler.all(event) do |handler|
          handlers[handler.underscore_name] ||= {
            'type' => 'object',
            'properties' => {
              'disabled' => {'type' => 'boolean'},
              'timeout' => {'type' => 'string'},
            },
          }
        end
      end
      return handlers
    end

    def controller
      return Environment.controller_name
    end
  end
end
