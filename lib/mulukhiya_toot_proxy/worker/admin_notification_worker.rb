module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(params)
      db.execute('notificatable_accounts', {id: params['id']}).each do |row|
        connect_slack(row['id']).say(create_message({
          account: db.execute('account', {id: params['id']}).first,
          status: params['status'],
        }), :text)
      rescue => e
        e = Error.create(e)
        Slack.broadcast(e.to_h)
        next
      end
    end

    private

    def connect_slack(id)
      return Slack.new(
        UserConfigStorage.new[id]['slack']['webhook'],
      )
    rescue
      raise ConfigError, 'Invalid webhook (Slack compatible)'
    end

    def create_message(params)
      return [
        "From: #{params[:account]['display_name']} (@#{params[:account]['username']})",
        params[:status],
      ].join("\n")
    end

    def db
      return Postgres.instance
    end
  end
end
