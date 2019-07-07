module MulukhiyaTootProxy
  class MentionNotificationWorker < NotificationWorker
    def perform(params)
      accounts = params['status'].scan(/@([[:word:]]+)(\s|$)/).map(&:first).uniq
      pattern = "(#{accounts.join('|')})"
      @db.execute('notificatable_accounts', {id: params['id'], pattern: pattern}).each do |row|
        next unless slack = connect_slack(row['id'])
        slack.say(create_message({
          account: Account.new({id: params['id']}),
          status: params['status'],
        }), :text)
      rescue Ginseng::ConfigError
        next
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.concat({row: row}))
        next
      end
    end
  end
end
