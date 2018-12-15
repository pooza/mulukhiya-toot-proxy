module MulukhiyaTootProxy
  class AdminNotificationWorker < NotificationWorker
    def perform(params)
      db.execute('notificatable_accounts', {id: params['id']}).each do |row|
        next unless slack = connect_slack(row['id'])
        slack.say(create_message({
          account: db.execute('account', {id: params['id']}).first,
          status: params['status'],
        }), :text)
      rescue
        next
      end
    end
  end
end
