module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true if Handler.create('user_tag').disable?
      return super
    end

    def perform(params = {})
      accounts(params).each do |account|
        account.user_config.clear_tags
        info_agent_service&.notify(account, worker_config(:message))
      end
    end

    def accounts(params = {})
      return UserConfigStorage.tag_owners.to_a unless id = params[:account_id]
      return [account_class[id]]
    end
  end
end
