module Mulukhiya
  class MentionNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return /(\s|^)@[[:word:]]+(\s|$)/.match?(body[status_field])
    end
  end
end
