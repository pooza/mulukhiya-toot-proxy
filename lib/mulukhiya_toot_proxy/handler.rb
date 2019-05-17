require 'timeout'
require 'httparty'
require 'rest-client'

module MulukhiyaTootProxy
  class Handler
    attr_accessor :tags
    attr_accessor :results
    attr_reader :mastodon
    attr_reader :local_tags

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
      return {handler: self.class.to_s, event: @event, entries: @result}
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

    def disable?
      return @config["/handler/#{underscore_name}/disable"]
    rescue Ginseng::ConfigError
      return false
    end

    alias disabled? disable?

    def events
      return [:pre_toot, :pre_webhook]
    end

    def self.create(name, params = {})
      require "mulukhiya_toot_proxy/handler/#{name}"
      return "MulukhiyaTootProxy::#{name.camelize}Handler".constantize.new(params)
    end

    def self.all(params = {})
      return enum_for(__method__) unless block_given?
      Config.instance['/handler/all'].each do |v|
        yield create(v, params)
      end
    end

    def self.exec_all(event, body, params = {})
      params[:results] ||= ResultContainer.new
      params[:tags] ||= TagContainer.new
      all(params.merge({event: event})) do |handler|
        next unless handler.events.include?(event)
        next if handler.disable?
        Timeout.timeout(handler.timeout) do
          handler.send("handle_#{event}".to_sym, body, params)
          params[:results].push(handler.result)
          params[:tags].concat(handler.local_tags)
        end
      rescue Timeout::Error => e
        Logger.new.error(e)
        next
      rescue RestClient::Exception => e
        raise Ginseng::GatewayError, e.message
      rescue HTTParty::Error => e
        raise Ginseng::GatewayError, e.message
      end
      return params[:results]
    end

    private

    def initialize(params = {})
      @config = Config.instance
      @logger = Logger.new
      @result = []
      @local_tags = []
      @mastodon = params[:mastodon] || Mastodon.new
      @tags = params[:tags] || TagContainer.new
      @results = params[:results] || ResultContainer.new
      @event = params[:event] || 'unknown'
    end

    def user_config
      return UserConfigStorage.new[mastodon.account_id]
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
