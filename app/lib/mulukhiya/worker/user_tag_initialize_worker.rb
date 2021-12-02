module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      accounts(params).select {|v| v.user_config['/tagging/user_tags'].present?}.each do |account|
        account.user_config.clear_tags
        info_agent_service.notify(account, config['/worker/user_tag_initialize/message'])
      end
    end

    def accounts(params = {})
      return UserConfigStorage.accounts.to_a unless id = params[:account_id]
      return [account_class[id]]
    end
  end
end
