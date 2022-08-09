module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true if Handler.create('user_tag').disable?
      return super
    end

    def perform(params = {})
      if id = params[:account_id]
        clear_user_tags(account_class[id])
      else
        UserConfigStorage.tag_owners.each do |account|
          clear_user_tags(account)
        end
      end
    end

    def clear_user_tags(account)
      account.user_config.clear_tags
      info_agent_service&.notify(account, worker_config(:message))
    end
  end
end
