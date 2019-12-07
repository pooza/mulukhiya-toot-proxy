module MulukhiyaTootProxy
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def contract
      @contract ||= "MulukhiyaTootProxy::#{command_name.classify}CommandContract".constantize.new
      return @contract
    end

    def handle_pre_toot(body, params = {})
      @parser = TootParser.new(body['status'])
      return unless @parser.exec
      return unless @parser.command_name == command_name
      errors = contract.call(@parser.params).errors.to_h
      raise Ginseng::RequestError, errors.values.join if errors.present?
      dispatch
      body['visibility'] = 'direct'
      body['status'] = status
      @result.push(@parser.params)
    end

    def handle_pre_webhook(body, params = {}); end

    def status
      return YAML.dump(@parser.params)
    end

    def dispatch
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
