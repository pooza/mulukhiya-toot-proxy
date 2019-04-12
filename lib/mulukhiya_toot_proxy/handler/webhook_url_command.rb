module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch(values); end

    def webhook
      unless @webhook
        @webhook = Webhook.new(UserConfigStorage.new[mastodon.account_id])
        raise Ginseng::RequestError, 'Invalid webhook' unless @webhook.exist?
      end
      return @webhook
    end

    def create_status(values)
      values['url'] = webhook.uri.to_s
      return YAML.dump(values)
    end
  end
end
