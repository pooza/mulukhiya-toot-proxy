module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def dispatch(values)
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end

    def exec(body, headers = {})
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account_id
      super(body, headers)
      body['status'] = YAML.dump(
        JSON.parse(UserConfigStorage.new.get(id)),
      )
    end
  end
end
