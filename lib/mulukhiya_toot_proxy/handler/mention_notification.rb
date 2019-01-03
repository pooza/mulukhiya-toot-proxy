module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def executable?(body, headers)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end
  end
end
