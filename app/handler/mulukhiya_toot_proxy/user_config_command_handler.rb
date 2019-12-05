module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return false
    end

    def dispatch
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account.id
      UserConfigStorage.new.update(id, @parser.params)
    end

    def status
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
