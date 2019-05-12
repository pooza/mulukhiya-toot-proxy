require 'json'
require 'yaml'

module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def dispatch_command(values)
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end

    private

    def create_status(values)
      v = JSON.parse(UserConfigStorage.new.get(mastodon.account_id)) || {}
      v['webhook'] ||= {}
      v['webhook']['url'] = webhook.uri.to_s if webhook.uri
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message
    end
  end
end
