require 'httparty'
require 'rest-client'

module Mulukhiya
  class Handler
    include Package
    include SNSMethods
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

    def handle_error(error, params = {}); end

    def handle_toot(body, params = {})
      params[:reporter] ||= Reporter.new
      params[:sns] ||= sns_class.new
      @sns = params[:sns]
      handle_pre_toot(body, params)
      return handle_post_toot(body, params)
    end

    def underscore
      return self.class.to_s.split('::').last.sub(/Handler$/, '').underscore
    end

    def verbose?
      return true
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
        handler: underscore,
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
      return config['/test/timeout'] if Environment.test?
      return config["/handler/#{underscore}/timeout"]
    rescue Ginseng::ConfigError
      return config['/handler/default/timeout']
    end

    def prepared?
      return @prepared.present?
    end

    def disable?
      return true unless Environment.dbms_class.config?
      return true if sns.account.disable?(self)
      return true if config.disable?(self)
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

    def self.create(name, params = {})
      return "Mulukhiya::#{name.camelize}Handler".constantize.new(params) rescue nil
    end

    def self.names
      names = []
      Event.all {|v| names.concat(v.handler_names.to_a)}
      return names.uniq.sort
    rescue => e
      logger.error(error: e)
      return nil
    end

    def self.search(pattern)
      return names.select {|v| v.match?(pattern) && !config.disable?(v)}
    end

    private

    def initialize(params = {})
      @result = []
      @errors = []
      @sns = params[:sns] || sns_class.new
      @reporter = params[:reporter] || Reporter.new
      @prepared = false
      @event = params[:event] || 'unknown'
    end
  end
end
