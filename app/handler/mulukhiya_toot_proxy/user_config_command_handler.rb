module MulukhiyaTootProxy
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return false
    end

    def dispatch
      raise Ginseng::GatewayError, 'Invalid access token' unless id = mastodon.account.id
      UserConfigStorage.new.update(id, @parser.params)
    end
  end
end
