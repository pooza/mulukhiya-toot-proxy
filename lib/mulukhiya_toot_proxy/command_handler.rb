module MulukhiyaTootProxy
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def handle_pre_toot(body, params = {})
      return nil unless values = parse(body['status'])
      dispatch_command(values)
      body['visibility'] = 'direct'
      body['status'] = create_status(values)
      @result.push(values)
    end

    def handle_pre_webhook(body, params = {}); end

    def parse(status)
      values = YAML.safe_load(status) || JSON.parse(status)
      return nil unless values&.is_a?(Hash)
      return nil unless values['command'] == command_name
      return values
    rescue Psych::DisallowedClass, Psych::SyntaxError, JSON::ParserError
      return nil
    end

    def create_status(values)
      return YAML.dump(values)
    end

    def dispatch_command(values)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias dispatch dispatch_command
  end
end
