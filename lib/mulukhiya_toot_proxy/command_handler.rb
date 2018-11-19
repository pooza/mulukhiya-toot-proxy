require 'yaml'
require 'json'

module MulukhiyaTootProxy
  class CommandHandler < Handler
    def command_name
      return underscore_name
    end

    def exec(body, headers = {})
      [:parse_yaml, :parse_json].each do |method|
        next unless values = send(method, body['status'])
        body['visibility'] = 'direct'
        body['status'] = YAML.dump(values)
        exec_command(values)
        break
      end
    end

    def parse_yaml(body)
      values = YAML.safe_load(body)
      return values if values['command'] == command_name
      return nil
    rescue
      return nil
    end

    def parse_json(body)
      values = JSON.parse(body)
      return values if values['command'] == command_name
      return nil
    rescue
      return nil
    end

    def exec_command(values)
      raise ImprementError, "#{__method__}が未定義です。"
    end
  end
end
