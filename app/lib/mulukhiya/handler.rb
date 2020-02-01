require 'timeout'
require 'httparty'
require 'rest-client'

module Mulukhiya
  class Handler
    attr_reader :results
    attr_reader :event
    attr_reader :sns

    def handle_pre_toot(body, params = {})
      return body
    end

    def handle_post_toot(body, params = {}); end

    def handle_pre_webhook(body, params = {})
      return handle_pre_toot(body, params)
    end

    def handle_post_webhook(body, params = {})
      handle_post_toot(body, params)
    end

    def handle_pre_upload(body, params = {}); end

    def handle_post_upload(body, params = {}); end

    def handle_post_fav(body, params = {}); end

    def handle_post_boost(body, params = {}); end

    def handle_post_bookmark(body, params = {}); end

    def handle_post_search(body, params = {}); end

    def underscore_name
      return self.class.to_s.split('::').last.sub(/Handler$/, '').underscore
    end

    def notifiable?
      return false
    end

    def result
      return nil unless @result.present?
      return {
        handler: underscore_name,
        event: @event.to_s,
        notifiable: notifiable?,
        entries: @result,
      }
    end

    def clear
      @result.clear
      @status = nil
      @parser = nil
      @prepared = false
      @results.clear
      @results.tags.clear
      @results.parser = nil
    end

    def timeout
      return @config["/handler/#{underscore_name}/timeout"]
    rescue Ginseng::ConfigError
      return @config['/handler/default/timeout']
    end

    def prepared?
      return @repared.present?
    end

    def disable?
      return true unless Postgres.config?
      return true if sns.account.disable?(underscore_name)
      return true if @config.disable?(underscore_name)
      return false
    rescue Ginseng::ConfigError, Ginseng::DatabaseError
      return false
    end

    alias disabled? disable?

    def parser
      unless @parser
        @parser = @results.parser || Environment.parser_class.new(@status)
        @results.parser = @parser
      end
      return @parser
    end

    def tags
      return @results.tags
    end

    def status_field
      return Environment.controller_class.status_field
    end

    def status_key
      return Environment.controller_class.status_key
    end

    def attachment_key
      return Environment.controller_class.attachment_key
    end

    def self.create(name, params = {})
      return "Mulukhiya::#{name.camelize}Handler".constantize.new(params)
    rescue Ginseng::ConfigError
      return nil
    end

    def self.all(event, params = {})
      config = Config.instance
      unless config["/#{Environment.controller_name}/events"].member?(event.to_s)
        raise "Invalid event '#{event}'"
      end
      config["/#{Environment.controller_name}/handlers/#{event}"].each do |v|
        yield create(v, params)
      end
    end

    def self.exec_all(event, body, params = {})
      params[:event] = event
      params[:results] ||= ResultContainer.new
      all(event, params) do |handler|
        next if handler.disable?
        Timeout.timeout(handler.timeout) do
          handler.send("handle_#{event}".to_sym, body, params)
        end
        params[:results].push(handler.result)
        break if handler.prepared?
      rescue Timeout::Error => e
        Logger.new.error(e)
      rescue RestClient::Exception, HTTParty::Error => e
        raise Ginseng::GatewayError, e.message, e.backtrace
      end
      return params[:results]
    end

    private

    def initialize(params = {})
      @config = Config.instance
      @logger = Logger.new
      @result = []
      @sns = params[:sns] || Environment.sns_class.new
      @results = params[:results] || ResultContainer.new
      @prepared = false
      @event = params[:event] || 'unknown'
    end
  end
end
