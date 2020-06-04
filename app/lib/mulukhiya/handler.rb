require 'httparty'
require 'rest-client'

module Mulukhiya
  class Handler
    attr_reader :reporter
    attr_reader :event
    attr_reader :sns
    attr_reader :errors
    attr_reader :result

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

    def handle_toot(body, params = {})
      params[:reporter] ||= Reporter.new
      params[:sns] ||= Environment.sns_class.new
      @sns = params[:sns]
      handle_pre_toot(body, params)
      return handle_post_toot(body, params)
    end

    def underscore_name
      return self.class.to_s.split('::').last.sub(/Handler$/, '').underscore
    end

    def verbose?
      return true
    end

    def notify(message)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(sns.account, message)
    end

    def summary
      return nil unless @result.present? || @errors.present?
      return {
        handler: underscore_name,
        event: @event.to_s,
        verbose: verbose?,
        result: @result,
        errors: @errors,
      }
    end

    def clear
      @result.clear
      @errors.clear
      @status = nil
      @parser = nil
      @prepared = false
      @reporter.clear
      @reporter.tags.clear
      @reporter.parser = nil
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
        @parser = @reporter.parser || Environment.parser_class.new(@status)
        @reporter.parser = @parser
      end
      return @parser
    end

    def tags
      return @reporter.tags
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
      params[:reporter] ||= Reporter.new
      all(event, params) do |handler|
        raise Ginseng::AuthError, 'Invalid token' unless handler.sns.account
        next if handler.disable?
        thread = Thread.new {handler.send("handle_#{event}".to_sym, body, params)}
        unless thread.join(handler.timeout)
          handler.errors.push(message: 'execution expired', timeout: "#{handler.timeout}s")
        end
        break if handler.prepared?
      rescue RestClient::Exception, HTTParty::Error => e
        handler.errors.push(class: e.class.to_s, message: e.message)
      ensure
        params[:reporter].push(handler.summary)
      end
      return params[:reporter]
    end

    private

    def initialize(params = {})
      @config = Config.instance
      @result = []
      @errors = []
      @sns = params[:sns] || Environment.sns_class.new
      @reporter = params[:reporter] || Reporter.new
      @prepared = false
      @event = params[:event] || 'unknown'
    end
  end
end
