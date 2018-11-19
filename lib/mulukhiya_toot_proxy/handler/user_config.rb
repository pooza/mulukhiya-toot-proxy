module MulukhiyaTootProxy
  class UserConfigHandler < CommandHandler
    def exec_command(values)
      raise DatabaseError, 'Invalid access token' unless id = mastodon.account_id
      UserConfigStorage.new.update(id, values)
    end
  end
end
