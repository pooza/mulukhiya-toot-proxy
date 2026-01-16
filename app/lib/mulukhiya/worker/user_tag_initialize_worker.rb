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
        log(mode: 'single')
        clear_user_tags(account_class[id])
      else
        log(mode: 'all')
        Parallel.each(UserConfigStorage.tag_owners, in_threads: Parallel.processor_count * 2) do |account|
          clear_user_tags(account)
        end
      end
    end

    def clear_user_tags(account)
      account.user_config.clear_tags
      info_agent_service&.notify(account, worker_config(:message))
      log(acct: account.acct.to_s, message: 'initialized')
    rescue => e
      e.log
    end
  end
end
