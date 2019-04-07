require 'timeout'
require 'httparty'
require 'rest-client'

module MulukhiyaTootProxy
  class Handler
    attr_accessor :mastodon
    attr_accessor :tags
    attr_accessor :results

    def exec(body, headers = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def underscore_name
      return self.class.to_s.split('::').last.sub(/Handler$/, '').underscore
    end

    def summary
      return "#{self.class.to_s.split('::').last},#{@result.count}"
    end

    def result
      return nil unless @result.present?
      return {handler: self.class.to_s, entries: @result}
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

    def self.exec_all(body, headers, params = {})
      logger = Logger.new
      tags = TagContainer.new
      results = ResultContainer.new
      all do |handler|
        Timeout.timeout(handler.timeout) do
          handler.mastodon = params[:mastodon]
          handler.tags = tags
          handler.results = results
          handler.exec(body, headers)
          results.push(handler.result) if handler.result
        end
      rescue Timeout::Error => e
        logger.error(Ginseng::Error.create(e).to_h)
        next
      rescue RestClient::Exception => e
        raise GatewayError, e.message
      rescue HTTParty::Error => e
        raise GatewayError, e.message
      end
      return results
    end

    private

    def initialize
      @config = Config.instance
      @logger = Logger.new
      @tags = TagContainer.new
      @results = ResultContainer.new
      @result = []
    end
  end
end
