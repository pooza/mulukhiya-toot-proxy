module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def notifiable?(body)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end
  end
end
