require 'yaml'
require 'json'

module MulukhiyaTootProxy
  class UserConfigHandler < CommandHandler
    def exec_command(values)
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
