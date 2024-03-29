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
          Environment.controller_name.to_sym => Environment.controller_class.schema,
          :handler => Handler.all_schema,
        )
        @schema[:required].push('controller') unless Environment.controller_name == 'mastodon'
        @schema[:required].push(Environment.controller_name, Environment.dbms_name)
        @schema.deep_stringify_keys!
      end
      return @schema
    end

    def about
      return {
        package: raw.dig('application', 'package'),
        config: {
          controller: self['/controller'],
          status: Environment.status_class.default,
        },
      }
    end
  end
end
