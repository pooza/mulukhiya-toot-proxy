module MulukhiyaTootProxy
  class ResultNotificationWorker < NotificationWorker
    sidekiq_options retry: false

    def perform(params)
      return unless slack = Account.new(id: params['account_id']).slack
      slack.say(YAML.dump(params['results']), :text)
    rescue Ginseng::ConfigError
      return
    rescue => e
      @logger.error(e)
    end
  end
end
