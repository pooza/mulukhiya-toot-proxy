module MulukhiyaTootProxy
  class AdminNotificationWorker < NotificationWorker
    def perform(params)
      @db.begin
      account = Mastodon.lookup_account(params['from_account_id'])
      @db.execute('notificatable_accounts', {id: account['id']}).each do |row|
        update_timeline({
          status_id: params['status_id'],
          account_id: row['id'],
          from_account_id: account['id'],
        })
        next unless slack = connect_slack(row['id'])
        slack.say(create_message({account: account, status: params['status']}), :text)
      rescue Ginseng::ConfigError
        next
      rescue => e
        @logger.error(e)
        next
      end
      @db.commit
    end

    private

    def update_timeline(params)
      @db.execute('insert_mention', {
        status_id: params[:status_id],
        account_id: params[:account_id],
      })
      @db.execute('insert_notification', {
        activity_id: @db.execute('last_mention_seq').first['id'],
        activity_type: 'Mention',
        from_account_id: params[:from_account_id],
        account_id: params[:account_id],
      })
    rescue => e
      @logger.error(e)
    end
  end
end
