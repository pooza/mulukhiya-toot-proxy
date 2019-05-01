module MulukhiyaTootProxy
  class WebhookURLCommandHandler < CommandHandler
    def dispatch(values)
      update_token(mastodon.account_id, nil) if values['update']
      raise Ginseng::RequestError, 'Invalid webhook' unless webhook
    end

    private

    def webhook
      unless @webhook
        unless @user_config[mastodon.account_id]['/webhook/token']
          rows = @db.execute('webhook_tokens', {id: mastodon.account_id})
          raise Ginseng::ConfigError, 'Access token not found' unless rows.present?
          update_token(mastodon.account_id, rows.first['token'])
        end
        @webhook = Webhook.new(@user_config[mastodon.account_id])
        raise GatewayError::ConfigError, 'Invalid webhook' unless @webhook.exist?
      end
      return @webhook
    rescue => e
      @logger.error(e)
      return nil
    end

    def update_token(id, token)
      @user_config.update(id, {webhook: {token: token}})
    end

    def create_status(values)
      values['url'] = webhook.uri.to_s
      values['token'] = webhook.mastodon.token
      return YAML.dump(values)
    end

    def initialize
      @user_config = UserConfigStorage.new
      @db = Postgres.instance
      super
    end
  end
end
