module MulukhiyaTootProxy
  class FavNotificationWorker < NotificationWorker
    def perform(params)
      Slack.broadcast(params)
    end
  end
end
