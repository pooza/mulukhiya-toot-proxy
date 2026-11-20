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
    #
    # ⚠⚠ **外すのは実況のために付けた 1 つだけ（`/decoration/live/id`・#4912）。**付ける前の状態で
    # 丸ごと上書きしないので、番組の途中で動かしたり足したりしたデコは残る。
    # ⚠ `notify:` は、利用者が自分で戻した（手で戻す口・タグセットを外した）ときは false。
    def restore_decoration(account, notify: true)
      Sidekiq.remove_schedule("decoration_initialize_#{account.username}")
      config = account.user_config
      live = self.class.live(config)
      service = sns_class.new
      service.token = config.token
      decorations = restored_decorations(service, account)
      service.update_account(avatarDecorations: decorations) if decorations
      config.update(decoration: {live: nil, saved_state: nil})
      return unless decorations
      info_agent_service&.notify(account, message(live)) if notify
      log(acct: account.acct.to_s, message: 'restored')
    rescue => e
      e.log
    end

    # 戻したあとのデコ。外すものが無ければ nil。
    #
    # ⚠ 外す相手は `/decoration/live/id`。5.48.0 より前に付けた分（`live` が無く `saved_state` がある）は、
    # 設定のデコ（`/decoration/id`）を外す相手にする。
    # ⚠⚠ **どちらも無ければ何もしない。**付けたことが分からないデコを外すと、利用者のデコを消す
    # （2026-08-23・11-12 にダイスキーで起きた）。
    def restored_decorations(service, account)
      return nil unless decoration_id = applied_decoration_id(account.user_config)
      current = service.fetch_account_detail['avatarDecorations'] || []
      return nil unless current.any? {|d| d['id'] == decoration_id}
      current = current.reject {|d| d['id'] == decoration_id}
      return current.map {|d| d.slice(*VALID_KEYS).compact}
    end

    def applied_decoration_id(config)
      return config['/decoration/live/id'] if self.class.live(config)
      return config['/decoration/id'] if config['/decoration/saved_state'].present?
      return nil
    end

    # 通知の文面。番組名・デコ名が分からなければ、その部分を一般的な言い方にする。
    def message(live)
      template = worker_config(:message)
      program = live['program'].present? ? "#{live['program']}の実況" : '実況'
      decoration = live['name'].present? ? "デコ「#{live['name']}」" : 'デコ'
      return template % {program:, decoration:}
    rescue ArgumentError, KeyError
      return template
    end

    LIVE_KEYS = ['started_at', 'id', 'name', 'program', 'restore_at'].freeze

    # 実況のために付けたデコの記録（`/decoration/live`）。無ければ nil。
    # ⚠ `UserConfig#[]` は末端のキーでしか引けない（`/decoration/live` は nil になる）ので、項目ごとに読む。
    # ⚠ 付けた印は `started_at`。既に同じデコを付けていた人は `id` が無い。
    def self.live(config)
      return nil unless config['/decoration/live/started_at'].present?
      return LIVE_KEYS.to_h {|key| [key, config["/decoration/live/#{key}"]]}.compact
    end

    # 戻す処理の対象か（実況のデコが付いているか）。
    def self.restorable?(config)
      return live(config).present? || config['/decoration/saved_state'].present?
    end

    # `/decoration/live` の API の中身 (#4912)。
    def self.live_status(config)
      return {live: false} unless live = live(config)
      return {live: true}.merge(live.slice('id', 'name', 'program', 'restore_at').symbolize_keys)
    end
  end
end
