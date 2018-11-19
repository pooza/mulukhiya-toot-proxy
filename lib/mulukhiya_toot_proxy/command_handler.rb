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
        dispatch(values)
        break
      end
    end

    def parse_yaml(body)
      values = YAML.safe_load(body)
      return nil unless values['command'] == command_name
      return value
    rescue
      return nil
    end

    def parse_json(body)
      values = JSON.parse(body)
      return nil unless values['command'] == command_name
      return value
    rescue
      return nil
    end

    def dispatch(values)
      raise ImprementError, "#{__method__}が未定義です。"
    end
  end
end
