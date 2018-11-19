module MulukhiyaTootProxy
  class UserConfigHandler < CommandHandler
    def dispatch(values)
      raise ExternalServiceError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end
  end
end
