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
      v['webhook']['url'] = mastodon.account.webhook.uri.to_s if mastodon.account.webhook
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message, e.backtrace
    end
  end
end
