module Mulukhiya
  class DecorationInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def perform(params = {})
      initialize_params(params)
      if id = params[:account_id]
        log(mode: 'single')
        restore_decoration(account_class[id])
      else
        log(mode: 'all')
        accounts = UserConfigStorage.decoration_owners
        Parallel.each(accounts, in_threads: Parallel.processor_count * 2) do |account|
          restore_decoration(account)
        end
      end
    end

    def restore_decoration(account)
      service = sns_class.new
      service.token = account.user_config.token
      saved = account.user_config['/decoration/saved_state']
      service.update_account(avatarDecorations: saved || [])
      account.user_config.update(decoration: {saved_state: nil})
      info_agent_service&.notify(account, worker_config(:message))
      log(acct: account.acct.to_s, message: 'restored')
    rescue => e
      e.log
    end
  end
end
