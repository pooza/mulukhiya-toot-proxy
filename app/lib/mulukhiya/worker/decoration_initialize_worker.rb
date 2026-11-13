module Mulukhiya
  class DecorationInitializeWorker < Worker
    sidekiq_options retry: false

    VALID_KEYS = ['id', 'angle', 'flipH', 'offsetX', 'offsetY'].freeze

    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def perform(params = {})
      # cron 2 3 * * *。Misskey 以外のサーバーでも decoration_owners を引いて
      # Misskey 固有の update_account を全アカウント分呼び、rescue でログだけが
      # 積み上がる (#4506)。
      return if disable?
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

    # ⚠⚠ 手で戻す口（`/decoration/restore`）から呼ばれても、予約を消す (#4912)。
    # 消さないと番組の終わりにもう一度動き、戻したあとのデコに手を出す。
    def restore_decoration(account)
      Sidekiq.remove_schedule("decoration_initialize_#{account.username}")
      service = sns_class.new
      service.token = account.user_config.token
      return unless decorations = restored_decorations(service, account)
      service.update_account(avatarDecorations: decorations)
      account.user_config.update(decoration: {saved_state: nil})
      info_agent_service&.notify(account, worker_config(:message))
      log(acct: account.acct.to_s, message: 'restored')
    rescue => e
      e.log
    end

    # 戻す先のデコ。戻す必要が無ければ nil。
    #
    # ⚠⚠ **`saved_state` が無いときに `[]` で上書きしない (#4912)。**無いのは
    # 「付ける前にデコが無かった」（空の配列は `UserConfigStorage#update` の `deep_compact` で消える）か
    # 「もう戻した」かのどちらか。どちらも、付けたデコだけを外せば足りる。丸ごと空にすると、
    # 手で戻したあとの予約が利用者のデコを全部消す（2026-08-23・11-12 にダイスキーで起きた）。
    def restored_decorations(service, account)
      saved = account.user_config['/decoration/saved_state']
      return saved if saved.present?
      return nil unless decoration_id = account.user_config['/decoration/id']
      current = service.fetch_account_detail['avatarDecorations'] || []
      return nil unless current.any? {|d| d['id'] == decoration_id}
      current = current.reject {|d| d['id'] == decoration_id}
      return current.map {|d| d.slice(*VALID_KEYS).compact}
    end
  end
end
