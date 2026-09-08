module Mulukhiya
  # 辞書ソース取得専用の HTTP クライアント (#4689)。
  #
  # ⚠⚠ **404 を再送対象にするのはここだけ。**`Mulukhiya::HTTP` 全体でやると、
  # 投稿経路や API クライアントまで巻き込んで **恒久的な 404 を retry_limit 倍
  # 叩き直すだけ**になる。上流（`Ginseng::HTTP::RetryMethods#retryable?`）が
  # 404 を外しているのは**意図的な設計**で、「401 / 403 / 422 を投げ直しても
  # 結果は同じ」という一般論としては正しい。
  #
  # ⚠ **404 が一時的なのは GAS という相手の事情**であって一般には成り立たないので、
  # 上流を変えにいく話ではない。`retryable?` は「方針を変えたいアプリは override する」
  # と明記されている面（pooza/tomato-shrieker の `retry_not_found` に前例がある）。
  class DictionaryHTTP < HTTP
    # 辞書取得での再送回数の既定 (#4689)。
    #
    # ⚠⚠ **時間の見積もりを先に置く。**#4659 の実測で **404 になった回は遅い**
    # （`seconds: 33.47`）。`/http/timeout/seconds: 30` と `/http/retry/seconds: 1` の
    # もとでは、1 ソースあたりの最悪が
    #
    #   limit × timeout + (limit - 1) × retry_seconds
    #
    # になる。**limit 2 で 61 秒 / limit 3 で 92 秒。**`TaggingDictionaryUpdateWorker` は
    # `every: 10m`（600 秒）で、⚠ **ソースは `Parallel.each` で並列に引く**ので
    # 壁時計はソース数倍にはならない（スレッド数を超えない限り）。
    #
    # ⚠ **既定を 2（＝再送 1 回）にしたのは上流負荷とのつり合い。**間欠 404 は
    # gomander で 1 日 38% の回に出るので、1 回の再送で取りこぼしは 38% → 約 14% に
    # 落ちる。⚠⚠ **再送は #4690（取得回数を減らす）とちょうど逆に効く**ので、
    # 増やすなら総リクエスト数で見ること。
    DEFAULT_RETRY_LIMIT = 2

    # 辞書取得で再送する 4xx。⚠ **GAS の間欠 404 のためだけに開けている。**
    RETRYABLE_CLIENT_STATUSES = [404].freeze

    # ⚠ **`retry_limit` の reader を潰さない。**`Ginseng::HTTP` は
    # `attr_accessor :retry_limit` を持ち、呼び出し側が `http.retry_limit = 1` で
    # 絞る使い方がある（`rss20_feed_renderer` / `media_metadata_storage`）。
    # メソッドで上書きすると**その代入が黙って効かなくなる**ので、
    # `@retry_limit` を差し替える形にする。
    def initialize
      super
      @retry_limit = configured_retry_limit
    end

    private

    def configured_retry_limit
      return config['/handler/dictionary_tag/retry/limit']
    rescue Ginseng::ConfigError
      # 既定値は config/application.yaml にある。設定ファイルが古い環境でも
      # 再送回数が未定義にならないための定数フォールバック。
      return DEFAULT_RETRY_LIMIT
    end

    # ⚠ **`super` を先に通す。**pinning / 上限超過 / 5xx / 接続断の判定は上流のまま。
    # ここで足すのは 404 だけ。
    #
    # ⚠⚠ **`instance_of?` で見る（PR #4710 の Codex P1）。**上流が明示的に落として
    # いる `PinningError` / `TooLargeError` は **`GatewayError` のサブクラス**なので、
    # `is_a?` で拾うと **`source_status` がたまたま 404 のときに上流のガードを
    # すり抜ける**。pinning は設定の問題で試行の間に変わらず、上限超過は同じ場所で
    # 超えるだけなので、再送してはいけない。
    #
    # ⚠ **サブクラスを列挙しない**のは、上流がガードを増やしたときに自動で追随する
    # ため。上流のレスポンス由来の 404 は `GatewayError.new("Bad response 404")`
    # ＝ **素の `GatewayError`** なので、これで過不足なく拾える。
    def retryable?(error)
      return true if super
      return false unless error.instance_of?(Ginseng::GatewayError)
      return RETRYABLE_CLIENT_STATUSES.include?(error.source_status)
    end
  end
end
