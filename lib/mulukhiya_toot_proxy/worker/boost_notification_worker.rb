module MulukhiyaTootProxy
  class BoostNotificationWorker < NotificationWorker
    def perform(params)
      account = Account.new(id: params['account_id'])
      toot = Toot.new(id: params['status_id'])
      toot.account.slack.say(create_message(account: account, toot: toot), :text)
    rescue Ginseng::ConfigError
      return
    end

    def template_name
      return 'boost_notification'
    end
  end
end
