require 'yaml'
require 'json'

module MulukhiyaTootProxy
  class UserConfigHandler < Handler
    def exec(body, headers = {})
      [:parse_yaml, :parse_json].each do |method|
        next unless values = send(method, body['status'])
        body['visibility'] = 'direct'
        body['status'] = YAML.dump(values)
        save(values)
        break
      end
    end

    def parse_yaml(body)
      values = YAML.safe_load(body)
      return values if values['user_config']
      return nil
    rescue
      return nil
    end

    def parse_json(body)
      values = JSON.parse(body)
      return values if values['user_config']
      return nil
    rescue
      return nil
    end

    def save(values)
      raise DatabaseError, 'Invalid access token' unless id = mastodon.account_id
      key = "user:#{id}"
      redis = Redis.new
      value = redis.get(key)
      dest = JSON.parse(value) if value.present?
      dest ||= {}
      dest.update(values)
      dest.compact!
      redis.set(key, dest.to_json)
      redis.save
    end
  end
end
