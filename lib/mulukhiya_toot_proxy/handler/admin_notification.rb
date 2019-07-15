module MulukhiyaTootProxy
  class AdminNotificationHandler < NotificationHandler
    def notifiable?(body)
      return false unless body['status'] =~ /#notify(\s|$)/i
      return false if body['visibility'] =~ /^(direct|private)$/
      return true if mastodon.account.admin?
      return true if mastodon.account.moderator?
      return false
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
