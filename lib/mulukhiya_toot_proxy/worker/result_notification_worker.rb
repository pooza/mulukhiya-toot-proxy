require 'yaml'

module MulukhiyaTootProxy
  class ResultNotificationWorker < NotificationWorker
    sidekiq_options retry: false

    def perform(params)
      return unless slack = connect_slack(params['id'])
      slack.say(create_message(params['results']), :text)
    rescue => e
      @logger.error(e)
    end

    def create_message(results)
      return YAML.dump(results)
    end
  end
end
