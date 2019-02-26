module MulukhiyaTootProxy
  class Handler
    attr_accessor :mastodon

    def initialize
      @config = Config.instance
      @count = 0
    end

    def exec(body, headers = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def underscore_name
      return self.class.to_s.split('::').last.sub(/Handler$/, '').underscore
    end

    def result
      return "#{self.class.to_s.split('::').last},#{@count}"
    end

    def timeout
      return @config["/handler/#{underscore_name}/timeout"]
    rescue Ginseng::ConfigError
      return @config['/handler/default/timeout']
    end

    def self.create(name)
      require "mulukhiya_toot_proxy/handler/#{name}"
      return "MulukhiyaTootProxy::#{name.camelize}Handler".constantize.new
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['/handlers'].each do |handler|
        yield create(handler)
      end
    end

    private

    def increment!
      @count += 1
    end
  end
end
