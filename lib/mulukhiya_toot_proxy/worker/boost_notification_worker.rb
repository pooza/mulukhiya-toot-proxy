module MulukhiyaTootProxy
  class BoostNotificationWorker < NotificationWorker
    def perform(params)
      Slack.broadcast(params)
    end
  end
end
