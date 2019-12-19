module MulukhiyaTootProxy
  class AdminNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return false unless (body[message_field]) =~ /#notify(\s|$)/i
      return false if body['visibility'] =~ /^(direct|private)$/
      return true if sns.account.admin?
      return true if sns.account.moderator?
      return false
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
