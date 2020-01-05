module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return body[status_field] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end
  end
end
