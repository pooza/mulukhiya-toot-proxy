module Mulukhiya
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def contract
      @contract ||= "Mulukhiya::#{command_name.camelize}CommandContract".constantize.new
      return @contract
    rescue => e
      e.log
      return nil
    end

    def validate
      return contract.call(parser.params).errors.to_h do |error|
        ["/#{error.path.map(&:to_s).join('/')}", error.text]
      end
    end

    def handle_pre_toot(payload, params = {})
      self.payload = payload
      return unless parser.command_name == command_name
      raise Ginseng::ValidateError, validate if validate.present?
      payload[visibility_field] = controller_class.visibility_name(:direct)
      payload.delete(spoiler_field)
      payload.delete(attachment_field)
      payload.delete(poll_field)
      @break = true
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
      @break = true
    end

    def handle_post_toot(payload, params = {})
      self.payload = payload
      return unless parser.command_name == command_name
      exec
      result.push(parser.params.select {|_, v| v.present?})
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, status: @status)
    end

    def handle_pre_webhook(payload, params = {})
    end

    def handle_post_webhook(payload, params = {})
    end

    def verbose?
      return false
    end

    def exec
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
