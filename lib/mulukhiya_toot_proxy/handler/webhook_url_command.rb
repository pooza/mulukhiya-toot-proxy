module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch_command(values)
      raise Ginseng::RequestError, 'Invalid webhook' unless mastodon.account.webhook&.uri
      raise Ginseng::RequestError, 'Invalid token' unless mastodon.token
    end

    def create_status(values)
      values['url'] = mastodon.account.webhook&.uri.to_s
      values['token'] = mastodon.token
      return YAML.dump(values)
    end
  end
end
