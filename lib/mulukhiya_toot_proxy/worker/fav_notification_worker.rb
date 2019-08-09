module MulukhiyaTootProxy
  class FavNotificationWorker < NotificationWorker
    def perform(params)
      from_account = Account.new(id: params['account_id'])
      toot = Toot.new(id: params['status_id'])
      pattern = "^#{toot.account.username}$"
      @db.execute('notificatable_accounts', {id: from_account.id, pattern: pattern}).each do |row|
        account = Account.new(id: row['id'])
        next unless account.config['/slack/webhook'].present?
        account.slack.say(create_message(account: from_account, toot: toot), :text)
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(row: row))
        next
      end
    end

    def template_name
      return 'fav_notification'
    end
  end
end
