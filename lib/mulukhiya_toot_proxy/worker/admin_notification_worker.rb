module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(params)
      db = Postgres.instance
      db.execute('notificatable_accounts', {id: params['id']}).each do |row|
        Slack.broadcast(UserConfigStorage.new[row['id']])
      end
    end
  end
end
