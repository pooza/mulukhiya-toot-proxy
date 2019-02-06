module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch(values)
      values.delete('url')
      webhook = Webhook.new(UserConfigStorage.new[mastodon.account_id])
      raise Ginseng::RequestError, 'Invalid webhook' unless webhook.exist?
      raise Ginseng::RequestError, 'Invalid webhook' unless values['url'].present?
      values['url'] = webhook.uri.to_s
    end
  end
end
