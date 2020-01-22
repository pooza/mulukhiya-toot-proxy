module Mulukhiya
  class AdminNotificationHandler < NotificationHandler
    def disable?
      return true unless Postgres.config?
      return super
    end

    def notifiable?(body)
      return false unless /#notify(\s|$)/i.match?((body[status_field]))
      return false if /^(direct|private)$/.match?(body['visibility'])
      return true if sns.account.admin?
      return true if sns.account.moderator?
      return false
    rescue => e
      @logger.error(e)
      return false
    end
  end
end
