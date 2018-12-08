module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(params)
      Slack.broadcast(params)
    end
  end
end
