module MulukhiyaTootProxy
  class FavNotificationWorker < NotificationWorker
    def perform(params)
      account = Account.new(id: params['account_id'])
      toot = Toot.new(id: params['status_id'])
      toot.account.slack&.say(create_message(account: account, toot: toot), :text)
    rescue => e
      @logger.error(e)
    end

    def template_name
      return 'fav_notification'
    end
  end
end
