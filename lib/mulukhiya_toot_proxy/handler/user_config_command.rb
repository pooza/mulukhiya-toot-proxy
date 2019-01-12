module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def dispatch(values)
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end
  end
end
