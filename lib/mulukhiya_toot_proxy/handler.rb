require 'timeout'
require 'httparty'
require 'rest-client'

module MulukhiyaTootProxy
  class Handler
    attr_accessor :tags
    attr_accessor :results
    attr_reader :mastodon
    attr_reader :user_config

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

    def clear
      @tags.clear
      @result.clear
    end

    def timeout
      return @config["/handler/#{underscore_name}/timeout"]
    rescue Ginseng::ConfigError
      return @config['/handler/default/timeout']
    end

    def mastodon=(mastodon)
      @mastodon = mastodon
      @user_config = UserConfigStorage.new[mastodon.account_id]
      @webhook = nil
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
        logger.error(e)
        next
      rescue RestClient::Exception => e
        raise Ginseng::GatewayError, e.message
      rescue HTTParty::Error => e
        raise Ginseng::GatewayError, e.message
      end
      return results
    end

    private

    def initialize
      @config = Config.instance
      @logger = Logger.new
      @mastodon = Mastodon.new
      @tags = TagContainer.new
      @result = []
      @results = ResultContainer.new
      clear
    end

    def webhook
      unless @webhook
        @webhook = Webhook.new(user_config)
        return nil unless @webhook.exist?
      end
      return @webhook
    rescue
      return nil
    end
  end
end
