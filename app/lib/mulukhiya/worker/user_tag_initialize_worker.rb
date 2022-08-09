module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true if Handler.create('user_tag').disable?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      if id = params[:account_id]
        clear_user_tags(account_class[id])
      else
        logger.info(class: self.class.to_s, mode: 'all users')
        UserConfigStorage.tag_owners.each do |account|
          clear_user_tags(account)
        end
      end
    end

    def clear_user_tags(account)
      account.user_config.clear_tags
      info_agent_service&.notify(account, worker_config(:message))
      logger.info(class: self.class.to_s, acct: account.acct.to_s, message: 'user tag initialized')
    rescue => e
      e.log
    end
  end
end
