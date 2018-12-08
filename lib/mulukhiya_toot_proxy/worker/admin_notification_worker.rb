module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(param)
      Slack.broadcast(param)
    end
  end
end
