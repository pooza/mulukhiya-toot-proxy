module MulukhiyaTootProxy
  class FavNotificationWorker < NotificationWorker
    def perform(params)
      from_account = Account[params['account_id']]
      toot = Toot[id: params['status_id']]
      pattern = "^#{toot.account.username}$"
      @db.execute('notificatable_accounts', {id: from_account.id, pattern: pattern}).each do |row|
        account = Account[row['id']]
        next unless account.config['/slack/webhook'].present?
        account.slack.say(create_message(account: from_account, toot: toot), :text)
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(row: row))
      end
    end

    def template_name
      return 'fav_notification'
    end
  end
end
