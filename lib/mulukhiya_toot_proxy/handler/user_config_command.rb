module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return false
    end

    def dispatch_command(values)
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account.id
      UserConfigStorage.new.update(id, values)
    end

    def create_status(values)
      v = JSON.parse(UserConfigStorage.new.get(mastodon.account.id)) || {}
      v['webhook'] ||= {}
      v['webhook']['url'] = webhook.uri.to_s if webhook.uri
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message
    end
  end
end
