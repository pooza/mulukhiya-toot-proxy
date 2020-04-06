module Mulukhiya
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def handle_toot(body, params = {})
      params[:reporter] ||= Reporter.new
      params[:sns] ||= Environment.sns_class.new
      @sns = params[:sns]
      handle_pre_toot(body, params)
      return handle_post_toot(body, params)
    end

    def contract
      @contract ||= "Mulukhiya::#{command_name.camelize}CommandContract".constantize.new
      return @contract
    end

    def errors
      return contract.call(parser.params).errors.to_h
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body unless parser.command_name == command_name
      raise Ginseng::ValidateError, errors.values.join if errors.present?
      body['visibility'] = Environment.controller_class.visibility_name('direct')
      body[status_field] = parser.params.to_yaml
      @prepared = true
      return body
    end

    def handle_post_toot(body, params = {})
      @status = body[status_field] || ''
      return unless parser.command_name == command_name
      dispatch
      @result.push(parser.params)
    end

    def handle_pre_webhook(body, params = {}); end

    def handle_post_webhook(body, params = {}); end

    def notifiable?
      return true
    end

    def dispatch
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
