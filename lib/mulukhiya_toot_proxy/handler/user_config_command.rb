module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def dispatch_command(values)
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end

    private

    def webhook
      unless @webhook
        @webhook = Webhook.new(UserConfigStorage.new[mastodon.account_id])
        return nil unless @webhook.exist?
      end
      return @webhook
    rescue
      return nil
    end

    def create_status(values)
      v = JSON.parse(UserConfigStorage.new.get(mastodon.account_id))
      v['webhook']['url'] = webhook.uri.to_s if webhook
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message
    end
  end
end
