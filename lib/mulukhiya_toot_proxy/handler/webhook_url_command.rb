module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch_command(values)
      raise Ginseng::RequestError, 'Invalid webhook' unless webhook
    end

    private

    def create_status(values)
      values['url'] = webhook.uri.to_s
      values['token'] = webhook.mastodon.token
      return YAML.dump(values)
    end
  end
end
