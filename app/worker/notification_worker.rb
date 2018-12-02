module MulukhiyaTootProxy
  class NotificationWorker
    include Sidekiq::Worker

    def perform(param)
      Slack.broadcast(param)
    end
  end
end
