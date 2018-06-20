require 'mulukhiya-toot-proxy/config'

module MulukhiyaTootProxy
  class Handler
    attr_reader :result

    def initialize
      @config = Config.instance
    end

    def exec
      raise 'execが未定義です。'
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['local']['handlers'].each do |handler|
        require "mulukhiya-toot-proxy/handler/#{handler}"
        yield "MulukhiyaTootProxy::#{handler.camelize}Handler".constantize.new
      end
    end
  end
end
