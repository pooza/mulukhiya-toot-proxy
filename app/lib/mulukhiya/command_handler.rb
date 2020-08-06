module Mulukhiya
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def contract
      @contract ||= "Mulukhiya::#{command_name.camelize}CommandContract".constantize.new
      return @contract
    end

    def command_params
      return parser.params
    end

    def validate
      return contract.call(command_params).errors.map do |error|
        ["/#{error.path.map(&:to_s).join('/')}", error.text]
      end.to_h
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body unless parser.command_name == command_name
      raise Ginseng::ValidateError, validate if validate.present?
      body['visibility'] = Environment.controller_class.visibility_name('direct')
      @prepared = true
      return body
    end

    def handle_post_toot(body, params = {})
      @status = body[status_field] || ''
      return unless parser.command_name == command_name
      exec
      result.push(parser.params)
    end

    def handle_pre_webhook(body, params = {}); end

    def handle_post_webhook(body, params = {}); end

    def verbose?
      return false
    end

    def exec
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
