module Mulukhiya
  class Config < Ginseng::Config
    include Package

    def local_file_path
      dirs.each do |dir|
        suffix = suffixes.find {|v| File.exist?(File.join(dir, "local#{v}"))}
        return File.join(dir, "local#{suffix}") unless suffix.nil?
      end
      return nil
    end

    def update_file(values)
      return unless path = local_file_path
      File.write(path, raw['local'].deep_merge(values.deep_stringify_keys).to_yaml)
    end

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
        @schema[:required].concat([Environment.controller_name, Environment.dbms_name])
        @schema.deep_stringify_keys!
      end
      return @schema
    end
  end
end
