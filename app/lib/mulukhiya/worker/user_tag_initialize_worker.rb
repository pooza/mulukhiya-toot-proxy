module Mulukhiya
  class UserTagInitializeWorker
    include Sidekiq::Worker
    sidekiq_options retry: 3

    def perform(params = {})
      accounts(params) do |account|
        next unless account.user_config['/tagging/user_tags'].present?
        account.user_config.clear_tags
      end
    end

    def accounts(params)
      return UserConfigStorage.accounts unless id = params['account']
      yield Environment.account_class[id]
    end
  end
end
