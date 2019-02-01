module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch(values)
      webhook = Webhook.new(UserConfigStorage.new[mastodon.account_id])
      return unless webhook.exist?
      values['url'] = webhook.uri.to_s
    end
  end
end
