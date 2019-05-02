module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch(values)
      raise Ginseng::RequestError, 'Invalid webhook' unless webhook
    end

    private

    def webhook
      unless @webhook
        @webhook = Webhook.new(@user_config[mastodon.account_id])
        raise GatewayError::ConfigError, 'Invalid webhook' unless @webhook.exist?
      end
      return @webhook
    rescue => e
      @logger.error(e)
      return nil
    end

    def create_status(values)
      values['url'] = webhook.uri.to_s
      values['token'] = webhook.mastodon.token
      return YAML.dump(values)
    end

    def initialize
      @user_config = UserConfigStorage.new
      super
    end
  end
end
