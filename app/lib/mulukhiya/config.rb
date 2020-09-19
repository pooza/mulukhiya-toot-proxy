require 'json-schema'

module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def disable?(handler_name)
      return self["/handler/#{handler_name}/disable"] == true
    rescue Ginseng::ConfigError
      return false
    end

    def keys(prefix)
      return map do |key, value|
        next unless key.start_with?(prefix)
        key.sub(Regexp.new("^#{prefix}"), '').split('/')[1]
      end.compact.sort.uniq
    end

    def errors
      return JSON::Validator.fully_validate(schema, raw['local'])
    end

    def self.load_file(name)
      name += '.yaml' if File.extname(name).empty?
      return YAML.load_file(File.join(Environment.dir, 'config', name))
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
