module MulukhiyaTootProxy
  class AdminNotificationHandler < NotificationHandler
    def notifiable?(body, headers)
      return false unless body['status'] =~ /#notify(\s|$)/i
      return false if body['visibility'] =~ /^(direct|private)$/
      return true if @mastodon.account['admin'] == 't'
      return true if @mastodon.account['moderator'] == 't'
      return false
    end
  end
end
