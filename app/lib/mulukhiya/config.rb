module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def load
      dirs.each do |dir|
        suffixes.each do |suffix|
          Dir.glob(File.join(dir, "*#{suffix}")).each do |f|
            key = File.basename(f, suffix)
            next if @raw.member?(key)
            @raw[key] = YAML.load_file(f)
          end
        end
      end
      basenames.reverse_each do |key|
        update(@raw[key].key_flatten) if @raw[key]
      end
    end

    alias reload load

    def disable?(handler)
      handler = Handler.create(handler.to_s) unless handler.is_a?(Handler)
      return self["/handler/#{handler.underscore}/disable"] == true rescue false
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
          handlers[handler.underscore] ||= handler.schema
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
