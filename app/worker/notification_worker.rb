module MulukhiyaTootProxy
  class NotificationWorker
    include Sidekiq::Worker

    def perform(id)
      Slack.broadcast(id)
    end
  end
end