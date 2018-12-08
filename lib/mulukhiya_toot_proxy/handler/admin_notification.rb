module MulukhiyaTootProxy
  class AdminNotificationHandler < SidekiqHandler
    def executable?
      return true if @mastodon.account['admin'] == 't'
      return true if @mastodon.account['moderator'] == 't'
      return false
    end

    def param
      return @mastodon.account_id
    end
  end
end
