module Mulukhiya
  class UserTagInitializeWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, unique: :until_executed

    def perform(params = {})
      accounts(params) do |account|
        next unless account.user_config['/tagging/user_tags'].present?
        account.user_config.clear_tags
        info_agent_service.notify(account, config['/tagging/user_tags/clear_message'])
      end
    end

    def accounts(params)
      return UserConfigStorage.accounts unless id = params['account_id']
      yield account_class[id]
    end
  end
end
