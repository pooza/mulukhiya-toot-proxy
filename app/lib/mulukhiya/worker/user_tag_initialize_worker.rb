module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      accounts = [account_class[params[:account_id]]] if params[:account_id]
      accounts ||= UserConfigStorage.tag_owners.to_a
      accounts.each do |account|
        account.user_config.clear_tags
        info_agent_service.notify(account, worker_config(:message))
      end
    end
  end
end
