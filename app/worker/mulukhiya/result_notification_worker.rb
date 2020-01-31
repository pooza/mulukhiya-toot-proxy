module Mulukhiya
  class ResultNotificationWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(params)
      message = [
        Environment.account_class[params['account_id']].acct.to_s,
        YAML.dump(params['results']),
      ]
      Environment.info_agent&.notify(
        Environment.controller_class.status_field => message.join("\n"),
        'visibility' => Environment.controller_class.visibility_name('direct'),
      )
    end
  end
end
