module Mulukhiya
  class Handler # rubocop:disable Metrics/ClassLength
    include Package
    include SNSMethods
    attr_reader :reporter, :event, :sns, :errors, :result, :payload, :text_field

    def name
      return self.class.to_s.split('::').last
    end

    def underscore
      return name.sub(/Handler$/, '').underscore
    end

    def handle_pre_toot(payload, params = {})
      return payload
    end

    def handle_post_toot(payload, params = {})
    end

    def handle_pre_webhook(payload, params = {})
      return handle_pre_toot(payload, params)
    end

    def handle_post_webhook(payload, params = {})
      handle_post_toot(payload, params)
    end

    def handle_pre_chat(payload, params = {})
      @text_field = chat_field
      return handle_pre_toot(payload, params)
    end

    def handle_post_chat(payload, params = {})
      @text_field = chat_field
      handle_post_toot(payload, params)
    end

    def handle_pre_upload(payload, params = {})
    end

    def handle_post_upload(payload, params = {})
    end

    def handle_pre_thumbnail(payload, params = {})
    end

    def handle_post_thumbnail(payload, params = {})
    end

    def handle_post_fav(payload, params = {})
    end

    def handle_post_boost(payload, params = {})
    end

    def handle_post_bookmark(payload, params = {})
    end

    def handle_post_reaction(payload, params = {})
    end

    def handle_announce(announcement, params = {})
    end

    def handle_follow(payload, params = {})
    end

    def handle_mention(payload, params = {})
    end

    def handle_error(error, params = {})
    end

    def handle_toot(payload, params = {})
      params[:reporter] ||= Reporter.new
      params[:sns] ||= sns_class.new
      @sns = params[:sns]
      handle_pre_toot(payload, params)
      return handle_post_toot(payload, params)
    end

    def handler_config(key)
      value = (config["/handler/#{underscore}/#{key}"] rescue nil)
      value = (config["/handler/#default/#{key}"] rescue nil) if value.nil?
      return value
    end

    def verbose?
      return true
    end

    def reportable?
      return false if verbose? && !sns.account&.notify_verbose? && errors.empty?
      return loggable?
    end

    def loggable?
      return result.present? || errors.present?
    end

    def summary
      return {
        event: @event.to_s,
        handler: underscore,
        entries: recursive_to_a(result.concat(errors)),
      }
    end

    def debug_info
      return {result:, errors:} if result.present? || errors.present?
      return nil
    end

    def schema
      return Config.load_file("schema/handler/#{underscore}")
    rescue
      return Config.load_file('schema/handler/default')
    end

    def clear
      @result.clear
      @errors.clear
      @status = nil
      @parser = nil
      @break = false
      @reporter.clear
      @reporter.tags.clear
      @reporter.parser = nil
    end

    def timeout
      return config['/handler/test/timeout']
    end

    def break?
      return @break.present?
    end

    def disable?
      return true unless Environment.dbms_class.config?
      return true if disableable? && sns.account&.disable?(self)
      return true if disableable? && config.disable?(self)
      return false
    rescue Ginseng::ConfigError, Ginseng::DatabaseError
      return false
    end

    def disableable?
      return true
    end

    alias disabled? disable?

    def payload=(payload)
      @payload = payload
      @status = payload[text_field] || ''
      @status.gsub!(/^#(nowplaying)[[:space:]]+(.*)$/i, '#\\1 \\2') if @status.present?
    end

    def flatten_payload
      parts = payload.slice(status_field, spoiler_field, chat_field).values
      parts.concat(payload.dig(poll_field, poll_options_field) || [])
      (payload[attachment_field] || []).map {|id| attachment_class[id]}.each do |attachment|
        parts.push(attachment.description)
      rescue => e
        e.log(attachment:)
      end
      return parts.compact.map {|v| v.gsub(Acct.pattern, '')}.join('::::')
    end

    def status_lines
      return nil unless @status
      return @status.each_line(chomp: true).to_a
    end

    def upload(uri, params = {})
      uri = Ginseng::URI.parse(uri) unless uri.is_a?(Ginseng::URI)
      raise "Invalid URL '#{uri}'" unless uri.absolute?
      params[:response] ||= :id
      return sns.upload_remote_resource(uri, params)
    end

    def parser
      unless @parser
        @parser = @reporter.parser || parser_class.new(@status)
        @reporter.parser = @parser
      end
      return @parser
    end

    def tags
      return @reporter.tags
    end

    def self.create(name, params = {})
      return "Mulukhiya::#{name.to_s.sub(/_handler$/, '').camelize}Handler".constantize.new(params)
    rescue => e
      e.log(name:)
      return nil
    end

    def self.names
      return Event.all.inject(Set[]) {|names, e| names.merge(e.handler_names.to_a)}
    rescue => e
      e.log
      return nil
    end

    def self.all_names
      return Event.all.inject(Set[]) {|names, e| names.merge(e.all_handler_names.to_a)}
    rescue => e
      e.log
      return nil
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      reporter = Reporter.new
      sns = sns_class.new
      all_names.map {|v| create(v, {reporter:, sns:})}.sort_by(&:underscore).each(&block)
    end

    def self.search(pattern)
      return names.select {|v| v.match?(pattern) && !config.disable?(v)}.to_set
    end

    def self.all_schema
      return {
        type: 'object',
        properties: Event.all.inject({}) do |props, e|
          props.merge(e.handlers.to_h {|v| [v.underscore, v.schema]}.deep_symbolize_keys)
        end,
      }
    end

    private

    def initialize(params = {})
      @result = []
      @errors = []
      @sns = params[:sns] || sns_class.new
      @reporter = params[:reporter] || Reporter.new
      @break = false
      @event = (params[:event] || 'unknown').to_sym
      @text_field = status_field
    end

    def recursive_to_a(arg)
      case arg
      in Hash
        return arg.deep_stringify_keys.transform_values do |v|
          v.is_a?(Set) ? v.to_a : recursive_to_a(v)
        end
      in Array | Set
        return arg.map {|v| v.is_a?(Set) ? v.to_a : recursive_to_a(v)}
      else
        return arg
      end
    end
  end
end
