require 'mulukhiya-toot-proxy/config'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/slack'

module MulukhiyaTootProxy
  class Handler
    def initialize
      @config = Config.instance
      @count = 0
    end

    def forward(body, headers = {})
      exec(body, headers)
      return body
    rescue => e
      message = {class: self.class.to_s, message: "#{e.class}: #{e.message}"}
      Logger.new.error(message)
      Slack.all.map{ |h| h.say(message)}
      return body
    end

    def exec
      raise 'execが未定義です。'
    end

    def result
      return "#{self.class.to_s.split('::').last},#{@count}"
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
