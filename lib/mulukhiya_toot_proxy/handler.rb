require 'timeout'
require 'httparty'
require 'rest-client'

module MulukhiyaTootProxy
  class Handler
    attr_accessor :tags
    attr_accessor :results
    attr_reader :mastodon
    attr_reader :user_config

    def handle_pre_toot(body, params = {})
      return nil
    end

    alias exec handle_pre_toot

    def handle_post_toot(body, params = {})
      return nil
    end

    def handle_pre_webhook(body, params = {})
      handle_pre_toot(body, params)
    end

    def handle_post_webhook(body, params = {})
      handle_post_toot(body, params)
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

    def enable?(name)
      return events.include?(name)
    end

    def mastodon=(mastodon)
      @mastodon = mastodon
      @user_config = UserConfigStorage.new[mastodon.account_id]
      @webhook = nil
    end

    def self.create(name, params = {})
      require "mulukhiya_toot_proxy/handler/#{name}"
      return "MulukhiyaTootProxy::#{name.camelize}Handler".constantize.new(params)
    end

    def self.all(params = {})
      return enum_for(__method__) unless block_given?
      Config.instance['/handlers'].each do |v|
        handler = create(v, params)
        yield handler
      end
    end

    def self.exec_all(event, body, params = {})
      results = params[:results] || ResultContainer.new
      all(params) do |handler|
        next unless handler.enable?(event)
        Timeout.timeout(handler.timeout) do
          handler.send("handle_#{event}".to_sym, body, params)
          results.push(handler.result)
        end
      rescue Timeout::Error => e
        Logger.new.error(e)
        next
      rescue RestClient::Exception => e
        raise Ginseng::GatewayError, e.message
      rescue HTTParty::Error => e
        raise Ginseng::GatewayError, e.message
      end
      return results
    end

    private

    def initialize(params = {})
      @config = Config.instance
      @logger = Logger.new
      @result = []
      @mastodon = params[:mastodon] || Mastodon.new
      @tags = params[:tags] || TagContainer.new
      @results = params[:results] || ResultContainer.new
      clear
    end

    def events
      return [:pre_toot, :pre_webhook]
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
