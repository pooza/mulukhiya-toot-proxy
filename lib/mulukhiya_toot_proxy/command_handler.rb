require 'yaml'
require 'json'

module MulukhiyaTootProxy
  class CommandHandler < Handler
    def command_name
      return self.class.to_s.split('::').last.sub(/CommandHandler$/, '').underscore
    end

    def handle_pre_toot(body, params = {})
      return if body['status'] =~ /^[[:digit:]]+$/
      values = {}
      [:parse_yaml, :parse_json].each do |method|
        break if values = send(method, body['status'])
      rescue => e
        @logger.error(e)
        next
      end
      return unless values.present?
      return unless values.is_a?(Hash)
      return unless values['command'] == command_name
      dispatch_command(values)
      body['visibility'] = 'direct'
      body['status'] = create_status(values)
      @result.push(values)
    end

    def create_status(values)
      return YAML.dump(values)
    end

    def parse_yaml(body)
      return YAML.safe_load(body)
    rescue
      return nil
    end

    def parse_json(body)
      return JSON.parse(body)
    rescue
      return nil
    end

    def dispatch_command(values)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias dispatch dispatch_command
  end
end
