module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch
      raise Ginseng::RequestError, 'Invalid webhook' unless mastodon.account.webhook
    end

    def status
      values = @parser.params.clone
      values['url'] = mastodon.account.webhook.uri.to_s
      values['token'] = mastodon.account.webhook.mastodon.token
      return YAML.dump(values)
    end
  end
end
