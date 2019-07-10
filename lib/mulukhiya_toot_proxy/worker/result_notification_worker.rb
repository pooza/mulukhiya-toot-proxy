module MulukhiyaTootProxy
  class ResultNotificationWorker < NotificationWorker
    sidekiq_options retry: false

    def perform(params)
      Account.new(id: params['account_id']).slack&.say(YAML.dump(params['results']), :text)
    rescue => e
      @logger.error(e)
    end
  end
end
