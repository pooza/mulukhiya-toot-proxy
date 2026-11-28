module Mulukhiya
  class DecorationApplyWorker < Worker
    sidekiq_options retry: false

    VALID_KEYS = ['id', 'angle', 'flipH', 'offsetX', 'offsetY'].freeze

    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def perform(params = {})
      # schedule は無く enqueue 経路のみだが、perform_async 以外から呼ばれても
      # 成立するよう他の worker と同じ形に揃える (#4506)。
      return if disable?
      initialize_params(params)
      account = account_class[params[:account_id]]
      apply_decoration(account, program: params[:program], restore_at: params[:restore_at])
    end

    # 実況のデコを付け、付けたことを `/decoration/live` に残す (#4912)。
    #
    # ⚠⚠ **番組の終わりには、ここで付けた 1 つだけを外す。**以前は付ける前の状態（`saved_state`）を
    # 丸ごと保存して上書きで戻していたので、番組の途中で動かしたり足したりしたデコが巻き戻った。
    # ⚠ 既に同じデコを付けていた人は、利用者のデコなので外さない（`live` に `id` を残さない）。
    # ⚠ 前の実況のデコが残っていて、設定のデコが変わっていたら、前のものを外して付け替える。
    #
    # ⚠⚠ **記録（`/decoration/live`）は、デコを付ける前に書く（5.48.0 のリリース前レビュー）。**付けてから
    # 書くと、書き込みが落ちたときに「付いているのに記録が無い」になり、番組の終わり・毎日の一括の戻し・
    # 手で戻す口のどれもが外さない。先に書いておけば、付けるほうが落ちても、戻すときに
    # 「記録の ID が付いていない」と見て何もしないだけで済む。
    # ⚠ 付け替えで付けるほうが落ちると、前の実況のデコが記録から外れて残る（Misskey の API が落ちたときだけ）。
    def apply_decoration(account, program: nil, restore_at: nil)
      service = sns_class.new
      service.token = account.user_config.token
      return unless decoration_id = account.user_config['/decoration/id']
      current = service.fetch_account_detail['avatarDecorations'] || []
      previous = account.user_config['/decoration/live/id']
      owned = previous != decoration_id && current.any? {|d| d['id'] == decoration_id}
      live = {started_at: Time.now.iso8601, program:, restore_at:}
      unless owned
        live[:id] = decoration_id
        live[:name] = decoration_name(service, decoration_id)
      end
      save_live(account, live)
      update_decorations(service, current, decoration_id, previous)
      log(acct: account.acct.to_s, decoration_id:, message: owned ? 'already applied' : 'applied')
    rescue => e
      e.log
    end

    # 付けるデコを足し、前の実況のデコ（設定のデコと違うもの）を外す。変わらなければ何もしない。
    def update_decorations(service, current, decoration_id, previous)
      original = current.map {|d| d.slice(*VALID_KEYS).compact}
      decorations = original.dup
      decorations.reject! {|d| d['id'] == previous} if previous && previous != decoration_id
      decorations.push({'id' => decoration_id}) if decorations.none? {|d| d['id'] == decoration_id}
      service.update_account(avatarDecorations: decorations) unless decorations == original
    end

    # ⚠ `update` は deep_merge なので、前の実況の項目は nil で明示して消す（残った `id` を外す相手と
    # 取り違えない）。書き込みは 1 回にまとめる。
    # ⚠⚠ **`update!` で書く（PR #4937 の Codex の P2）。**`update` は失敗を握りつぶして nil を返すので、
    # 記録が無いままデコを付けてしまう。例外で `apply_decoration` の rescue へ抜けて、付けずに終わる。
    # ⚠ `update` が持っていた `alert` はここで引き継ぐ。`apply_decoration` の rescue は `log` だけなので、
    # そのままだと実況中にデコが付かないことが Sentry に届かない（5.49.0 のリリース前レビュー）。
    def save_live(account, live)
      cleared = DecorationInitializeWorker::LIVE_KEYS.to_h {|key| [key.to_sym, nil]}
      account.user_config.update!(decoration: {live: cleared.merge(live)})
    rescue => e
      e.alert
      raise
    end

    # 通知の文面に使うデコの名前。取れなければ nil（文面は名前なしで組む）。
    def decoration_name(service, decoration_id)
      decorations = service.fetch_avatar_decorations
      return nil unless decorations.is_a?(Array)
      return decorations.find {|d| d['id'] == decoration_id}&.dig('name')
    rescue => e
      e.log
      return nil
    end
  end
end
