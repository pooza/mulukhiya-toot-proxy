module Mulukhiya
  # ロックが「黙って効かなくなった」ことを観測できるようにする (#4577 の 2)。
  #
  # ProgramLockStorage (#4534) と ComposeTemplateLockStorage (#4457 / #4460) は
  # 同型で、どちらも Redis 障害時はロックを諦めて実行を阻害しない (fail-open)。
  #
  # ⚠ **fail-open 自体は設計判断として正しい。**ロックのために編集そのものを
  # 止めるほうが悪い。問題は **発動したことがどこにも出ない**ことで、
  # `e.log` 止まりなので Sentry には 1 件も届かない。nil トークンで
  # `synchronize` が通ると、以後その呼び出しはロック無しで RMW を回し、
  # ProgramLockStorage のクラス doc 自身が書いている「単発の lost update が
  # **恒久的なロールバック**になる」状態が無警告で復活する。
  #
  # ⚠⚠ **`/health` の Redis チェックは `GET` 1 本なので、以下はどちらも
  # OK のまま素通りする。**
  #
  # - `RedisClient::Pool` のチェックアウト待ち（既定 5 秒）超過 — 実況ピークで起こりうる
  # - 🔴 **`EVAL` だけ通らない構成（ACL / scripting 制限）** — `acquire` は成功して
  #   `release` が毎回失敗するので、**すべての書き込みが TTL ぶんロックを持ち逃げ**し、
  #   エディタが延々 409 を返す。fail-open より静かで痛い
  #
  # ⚠ さらに `acquire` / `release` は `redis.call` 直叩きで、
  # `Ginseng::Redis::Service` の「1 秒 sleep × 3 回」リトライに乗っていない
  # （`get` / `set` は乗っている）。`redis-client` は既定で再接続しないので、
  # **Redis 再起動後に死んだ接続を掴んだ最初のコマンドは必ず例外** → fail-open。
  # 同じ瞬間 `data` と `fetcher.save` は Ginseng のリトライで成功するため、
  # **ユーザーからは完全に正常な 200** に見える。⚠ **リトライラッパへ載せる話は
  # 観測性ではなく耐性の変更なので #4742 へ切り出した。**
  module LockDegradationMethods
    # 同じ事象で鳴らす間隔（秒）。
    #
    # ⚠⚠ **`Program#save` は ProgramUpdateWorker から every 1m で呼ばれる。**
    # 素直に `alert` へ上げると、Redis が落ちている間じゅう**日 1,440 件**の
    # メール・Discord になる（#4573 で「周期実行の失敗をそのままアラートに
    # 載せない」と決めたのと同じ形）。
    #
    # ⚠ かといって `log` だけに倒すと **syslog を見に行かないと気付けない**ままで、
    # この Issue が挙げた穴が残る。**窓 1 回に絞って鳴らす。**
    #
    # ⚠ `Controller::ALERT_THROTTLE_SECONDS`（300）より長くしてある。あちらは
    # 要求ごとに立つ 5xx が相手だが、こちらは**毎分の周期実行**が相手で、
    # 300 秒だと 1 時間に 12 件鳴る。Redis の死そのものは `/health` と
    # Redis 接続系の Sentry が別途拾うので、ここで欲しいのは
    # 「ロックが効かないまま書いている」ことに気付ける頻度で足りる。
    FAIL_OPEN_ALERT_SECONDS = 3600

    # 抑止の鍵の接頭辞。⚠ **ストレージと事象の両方で分ける。**番組表のロックが
    # 鳴っている間に投稿テンプレのロックが黙る、fail-open が鳴っている間に
    # release 失敗が黙る、のはどちらも別の障害を隠す。
    THROTTLE_KEY_PREFIX = 'lock_degradation'.freeze

    private

    # ロックを諦めて素通しした（fail-open）。
    def note_fail_open(error, values = {})
      escalate(error, 'fail-open', values)
    end

    # ロックは取れたが解放に失敗した。
    def note_release_failure(error, values = {})
      escalate(error, 'release-failed', values)
    end

    # ⚠ **`alert` は `log` も撃つ**（`StandardError#alert` が内部で呼ぶ）ので、
    # 窓を取れなかった回だけ `log` する。両方呼ぶと syslog が二重になる。
    def escalate(error, state, values)
      payload = {lock: state, storage: underscore}.merge(values)
      return error.log(payload) unless throttle_class.acquire(
        throttle_key(state),
        FAIL_OPEN_ALERT_SECONDS,
      )
      error.alert(payload)
    end

    def throttle_key(state)
      return [THROTTLE_KEY_PREFIX, underscore, state].join('/')
    end

    # ⚠⚠ **Redis の印は使えない。**Redis が落ちている最中の話なので、
    # `Redis#acquire` へ寄せると抑止そのものが例外になる
    # （`Controller#acquire_alert_slot` が Redis を先に試せるのは、あちらが
    # 「Redis は健全かもしれない」場面だから）。プロセス内だけで持つ。
    def throttle_class
      return LocalAlertThrottle
    end
  end
end
