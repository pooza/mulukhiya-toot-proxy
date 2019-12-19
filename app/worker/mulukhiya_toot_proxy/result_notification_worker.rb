module MulukhiyaTootProxy
  class ResultNotificationWorker < NotificationWorker
    sidekiq_options retry: false

    def perform(params)
      Environment.account_class[params['account_id']].slack&.say(
        YAML.dump(params['results']),
        :text,
      )
    end
  end
end
