module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(params)
      db = Postgres.instance
      account = db.execute('account', {id: params['id']}).first
      db.execute('notificatable_accounts', {id: params['id']}).each do |row|
        userconfig = UserConfigStorage.new[row['id']]
        Slack.new(userconfig['slack']['webhook']).say({
          account: {
            username: account['username'],
            display_name: account['display_name'],
          },
          status: params['status'],
        })
      rescue => e
        e = Error.create(e)
        Slack.broadcast(e.to_h)
        next
      end
    end
  end
end
