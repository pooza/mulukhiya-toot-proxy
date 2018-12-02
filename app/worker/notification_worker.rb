class NotificationWorker
  include Sidekiq::Worker

  def perform(id)
    MulukhiyaTootProxy::Slack.broadcast(id)
  end
end
