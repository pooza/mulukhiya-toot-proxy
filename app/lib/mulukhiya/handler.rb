require 'httparty'
require 'rest-client'

module Mulukhiya
  class Handler
    attr_reader :reporter, :event, :sns, :errors, :result

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

    def handle_pre_chat(body, params = {})
      return handle_pre_toot(body, params)
    end

    def handle_post_chat(body, params = {})
      handle_post_toot(body, params)
    end

    def handle_pre_upload(body, params = {}); end

    def handle_post_upload(body, params = {}); end

    def handle_pre_thumbnail(body, params = {}); end

    def handle_post_thumbnail(body, params = {}); end

    def handle_post_fav(body, params = {}); end

    def handle_post_boost(body, params = {}); end

    def handle_post_bookmark(body, params = {}); end

    def handle_post_search(body, params = {}); end

    def handle_announce(announcement, params = {}); end

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

    def notify(message, response = nil)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(sns.account, message, response)
    end

    def reportable?
      return false if verbose? && !@sns.account.notify_verbose? && @errors.empty?
      return loggable?
    end

    def loggable?
      return @result.present? || @errors.present?
    end

    def summary
      return {
        event: @event.to_s,
        handler: underscore_name,
        entries: @result.concat(@errors).map do |entry|
          entry.is_a?(Hash) ? entry.deep_stringify_keys : entry
        end,
      }
    end

    def debug_info
      return {result: @result, errors: @errors} if @result.present? || @errors.present?
      return nil
    end

    def schema
      return {
        'type' => 'object',
        'properties' => {
          'disabled' => {'type' => 'boolean'},
          'timeout' => {'type' => 'string'},
        },
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
      return @config['/test/timeout'] if ENV['TEST']
      return @config["/handler/#{underscore_name}/timeout"]
    rescue Ginseng::ConfigError
      return @config['/handler/default/timeout']
    end

    def prepared?
      return @prepared.present?
    end

    def disable?
      return true unless Environment.dbms_class.config?
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

    def attachment_field
      return Environment.controller_class.attachment_field
    end

    def self.create(name, params = {})
      return "Mulukhiya::#{name.camelize}Handler".constantize.new(params)
    rescue Ginseng::ConfigError
      return nil
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
