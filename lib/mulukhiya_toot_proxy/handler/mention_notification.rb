module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def notifiable?(body, headers)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end
  end
end
