module MulukhiyaTootProxy
  class ResultNotificationWorker < NotificationWorker
    sidekiq_options retry: false

    def perform(params)
      return unless slack = connect_slack(params['id'])
      slack.say(create_message(params['results']), :text)
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h)
    end

    def create_message(results)
      return JSON.pretty_generate(results)
    end
  end
end
