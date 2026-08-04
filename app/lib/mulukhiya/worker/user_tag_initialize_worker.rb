module Mulukhiya
  class UserTagInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true if Handler.create('user_tag').disable?
      return super
    end

    def perform(params = {})
      # cron 2 3 * * *。🔴 user_tag ハンドラを無効にしたサーバーでも
      # clear_tags が走り、**利用者が設定済みのタグを毎日消してしまう**。
      # 7 本のうち唯一データを破壊する (#4506)。
      return if disable?
      initialize_params(params)
      if id = params[:account_id]
        log(mode: 'single')
        clear_user_tags(account_class[id])
      else
        log(mode: 'all')
        accounts = UserConfigStorage.tag_owners
        Parallel.each(accounts, in_threads: Parallel.processor_count * 2) do |account|
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
