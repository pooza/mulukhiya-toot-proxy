require 'mulukhiya-toot-proxy/config'

module MulukhiyaTootProxy
  class Handler
    def initialize
      @config = Config.instance
      @count = 0
    end

    def exec
      raise 'execが未定義です。'
    end

    def result
      return "#{self.class}:#{@count}"
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['local']['handlers'].each do |handler|
        require "mulukhiya-toot-proxy/handler/#{handler}"
        yield "MulukhiyaTootProxy::#{handler.camelize}Handler".constantize.new
      end
    end

    private

    def increment!
      @count += 1
    end
  end
end
