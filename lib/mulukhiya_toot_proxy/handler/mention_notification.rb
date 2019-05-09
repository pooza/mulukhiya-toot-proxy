module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def notifiable?(body)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
