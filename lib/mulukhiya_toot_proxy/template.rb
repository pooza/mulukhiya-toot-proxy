require 'erb'

module MulukhiyaTootProxy
  class Template
    def initialize(name)
      @path = File.join(ROOT_DIR, 'views', "#{name}.erb")
      @erb = ERB.new(File.read(@path), nil, '-')
      @params = {}.with_indifferent_access
    end

    def [](key)
      return @params[key]
    end

    def []=(key, value)
      value = value.with_indifferent_access if value.is_a?(Hash)
      @params[key] = value
    end

    def to_s
      return @erb.result(binding)
    end
  end
end
