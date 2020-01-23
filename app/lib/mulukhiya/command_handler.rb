module Mulukhiya
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def handle_root(body, params = {})
      params[:results] ||= ResultContainer.new
      params[:tags] ||= TagContainer.new
      handle_pre_toot(body, params)
      return handle_post_toot(body, params)
    end

    def contract
      @contract ||= "Mulukhiya::#{command_name.camelize}CommandContract".constantize.new
      return @contract
    end

    def errors
      return contract.call(@parser.params).errors.to_h
    end

    def handle_pre_toot(body, params = {})
      unless @parser = params[:results].parser
        params[:results].parser = @parser = create_parser(body[status_field])
      end
      return unless @parser.command?
      return unless @parser.command_name == command_name
      raise Ginseng::ValidateError, errors.values.join if errors.present?
      body['visibility'] = Environment.controller_class.visibility_name('direct')
      body[status_field] = status
      @prepared = true
    end

    def prepared?
      return @prepared.present?
    end

    def handle_post_toot(body, params = {})
      return unless @parser = params[:results].parser
      return unless @parser.command_name == command_name
      dispatch
      @result.push(@parser.params)
    end

    def handle_pre_webhook(body, params = {}); end

    def handle_post_webhook(body, params = {}); end

    def status
      return YAML.dump(@parser.params)
    end

    def dispatch
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
