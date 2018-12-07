module MulukhiyaTootProxy
  class NotificationHandler < SidekiqHandler
    def executable?
      return @mastodon.account['admin'] || @mastodon.account['moderator']
    end

    def param
      return 'あああああ'
    end
  end
end
