module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def notifiable?(body)
      return body[message_field] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end
  end
end
