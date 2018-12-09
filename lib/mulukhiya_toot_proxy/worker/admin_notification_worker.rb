require 'addressable/uri'

module MulukhiyaTootProxy
  class AdminNotificationWorker
    include Sidekiq::Worker

    def perform(params)
      db.execute('notificatable_accounts', {id: params['id']}).each do |row|
        next unless slack = connect_slack(row['id'])
        slack.say(create_message({
          account: db.execute('account', {id: params['id']}).first,
          status: params['status'],
        }), :text)
      rescue => e
        Slack.broadcast(Error.create(e).to_h)
        next
      end
    end

    private

    def connect_slack(id)
      return nil unless uri = Addressable::URI.parse(UserConfigStorage.new[id]['slack']['webhook'])
      return nil unless uri.absolute?
      return Slack.new(uri)
    rescue
      return nil
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
