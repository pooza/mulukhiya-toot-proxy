module Mulukhiya
  # コントローラ層の失敗の扱い（通知・抑止・利用者へ返す文言・上流エラーの判定）。
  #
  # ⚠ Controller の行数上限（`Metrics/ClassLength`）に当たったので、ひとまとまりで
  # 切り出した（中身は移しただけ）。定数も一緒に移したが、include しているので
  # `Controller::ALERT_THROTTLE_KEY_PREFIX` のように従来どおり参照できる。
  module ControllerErrorMethods
    # サーバー側の失敗を鳴らす間隔 (秒) と、その印を置く Redis キーの接頭辞 (#4693)。
    # ⚠ 型ごとに独立して数える。`Sequel::DatabaseConnectionError` の連打を抑えている間に
    # 別の型（本物のバグ）が出たら、そちらは 1 回目として鳴ってほしい。
    ALERT_THROTTLE_SECONDS = 300
    ALERT_THROTTLE_KEY_PREFIX = 'alert_throttle'.freeze

    # ルートが決まる前に落ちたときの発生源 (#4693・PR #4712 の Codex P2)。
    #
    # ⚠⚠ **ここは 1 つのバケツにまとめる。**`before` は全リクエストで走り、
    # **パスごとに分けると分けた数だけ鳴る**＝抑えたい相手そのものを取り逃がす。
    BEFORE_ORIGIN = 'before'.freeze

    # クライアント起因の失敗を Sentry alert に上げない共通判定
    # (#4542 / #4594 / #4603 / #4629 / #4654)。
    #
    # ⚠⚠ **コントローラ層の rescue はここ 1 本に寄せた (#4654)。**最上位の
    # `error` ブロックも含め、`e.log` / `e.alert` / `e.status < 500 ? ... : ...` の
    # 直書きは残さない。**唯一の例外は `WebhookController` の `post /admin`** で、
    # 署名不一致（4xx）を黙らせたくないという理由が現地に書いてある
    # （そこも連打は `throttled_alert` で抑える・#4723）。
    #
    # ⚠⚠ **例外クラスの列挙で判定しない。**同じ方針が 3 系統で別々に書かれ、
    # そのたびに取りこぼした——#4603 は `NotFoundError`、#4629 は `AuthError` と
    # `NotFoundError` が `else` へ落ちて alert していた。**ステータスで判定する**ので、
    # 新しい 4xx を投げても漏れない。
    #
    # ⚠ **抑止するのは Sentry だけ。syslog には必ず残す**（`handle_gateway_error` と
    # 同じ設計）。完全に無音だと「webhook が全滅している」ような事故の頻度・偏りを
    # 追えなくなる。
    #
    # ⚠ **素の `StandardError` は alert 側へ倒れる。**ginseng-core の refine が
    # `StandardError#status` に **500** を定義しているので、`NoMethodError` や
    # `Sequel::DatabaseConnectionError` は 4xx に当たらず alert される。
    # モロヘイヤ自身のバグを黙らせてはいけないので、これが正しい既定。
    # `respond_to?` のガードは refine が外れたときの保険で、通常は到達しない。
    def report_error(error)
      # ⚠⚠ **① 印が付いていればステータスに依らず必ず鳴らす (#4693)。**
      # 「403 だがこちらの設定が壊れている」型（`Ginseng::CryptError`）や
      # 「403 だがセキュリティ不変条件の破れ」型（`token_mismatch`・`AuthError`）が、
      # ステータスだけの判定では丸ごと無音になっていた。
      return error.alert if never_silent?(error)
      # ② クライアント起因は従来どおり log 止め。
      return error.log if client_error?(error)
      # ⚠⚠ **③ サーバー側の失敗は鳴らすが、連続はデッドマンで抑える (#4693)。**
      # `before` は**全リクエスト**（未認証・スキャナ由来を含む）で走り、失敗の
      # 主因は Redis / Postgres 障害。素通しだと **DB 全断中にリクエスト 1 本ごとに
      # Sentry イベント 1 件＋ slack / line / mail** が飛び、障害中に外向き HTTP を
      # 増やす二次被害とレート制限になる。
      return throttled_alert(error)
    end

    # 同じ型 × 同じ発生源の失敗は、窓のあいだ 1 回だけ鳴らす (#4693)。
    #
    # ⚠ `StartupNotificationWorker#notify_failure` と同じ「連続失敗の 1 回目だけ」の
    # 考え方だが、**成功で解除する代わりに TTL で解除する。**`before` は毎リクエスト
    # 走るので、成功のたびに Redis を書くと平常時のコストが乗る。
    #
    # ⚠ **抑止中の log には発生源を載せる。**抑止しているあいだは syslog が唯一の
    # 記録なので、どのルートで何件落ちたかを数えられないと意味が無い。
    def throttled_alert(error)
      return error.alert if acquire_alert_slot(alert_throttle_key(error))
      return error.log(throttled: true, origin: alert_throttle_origin)
    end

    # 鳴らす権利を獲得できたか。
    #
    # 🔴 **5.37.0 リリース前レビューの赤。**当初は `key?` → `setex` の 2 段で、
    # - `key?` の中身が **`KEYS`** で、**障害の最中に要求のたびに Redis を塞いでいた**
    #   （Mastodon と共有しているインスタンス。同じリリースの #4703 が
    #   「KEYS は本番の要求経路に乗らない」と書いたのと矛盾していた）
    # - `setex` の再送で、書き込みを拒む Redis では **5xx のたびに約 2 秒止まった**
    # - ⚠⚠ **書き込みを拒む Redis（ディスク満杯の MISCONF・OOM・READONLY）では、
    #   印が永遠に書けないので全ルートのサーバー側失敗が 1 回も鳴らなくなった。**
    #   しかも `/health` の redis は**読みしか試さない**ので OK のまま＝
    #   「Redis の死は /health が見る」という前提が崩れていた
    #
    # → **`SET NX EX` を再送なしで 1 回**撃つ。⚠⚠ **書けなかったら黙らせない。**
    # プロセス内の抑止へ倒す（`LocalAlertThrottle`）。**Redis が健全なら
    # クラスタ全体で 1 回、壊れていればプロセスごとに 1 回**鳴る。どちらでも
    # 「黙る」ことも「連打する」ことも無い。
    def acquire_alert_slot(key)
      return Redis.new.acquire(key, ALERT_THROTTLE_SECONDS)
    rescue => e
      logger.error(error: 'alert throttle unavailable', class: e.class.to_s, key:)
      return LocalAlertThrottle.acquire(key, ALERT_THROTTLE_SECONDS)
    end

    # 抑止のバケツ。**型だけでは粗すぎる（PR #4712 の Codex P2）。**
    #
    # ⚠⚠ `report_error` は `before` だけでなく**各コントローラの rescue から
    # 呼ばれる**ので、型だけで括ると **`RuntimeError` / `NoMethodError` のような
    # 広い型で、あるルートの失敗が別ルートの本物のバグを 300 秒握り潰す。**
    # 発生源（ルート）を混ぜて、**抑えたいのは「同じ場所の連打」だけ**にする。
    #
    # ⚠ `sinatra.route` は `"POST /api/v?/status/tags"` のような**パターン**なので、
    # id を含まず安定している（実測）。ルートが決まる前＝ `before` の失敗では nil。
    def alert_throttle_key(error)
      return [ALERT_THROTTLE_KEY_PREFIX, error.class, alert_throttle_origin].join('/')
    end

    # ⚠ リクエストの外（rake・テスト）では `request` が nil。**黙って倒すが、
    # 倒す先は「より強く抑える」側**なので、無音で緩むことにはならない。
    def alert_throttle_origin
      return BEFORE_ORIGIN unless request
      return request.env['sinatra.route'].presence || BEFORE_ORIGIN
    rescue StandardError
      return BEFORE_ORIGIN
    end

    # 利用者へ返してよい例外メッセージ。
    #
    # 🔴 **5xx の原文は返さない。**Redis や DB の接続エラーは接続先を含むので、
    # そのまま画面や本文へ出すと内部の構成が漏れる（#4724 の 1 で OAuth state の
    # 取り出し失敗を上げるようにしたら、`/oauth/callback` がこれを出しうるようになった）。
    # ⚠ 4xx は利用者が直せる理由なので従来どおり返す。
    def public_error_message(error)
      return error.message if error.respond_to?(:status) && error.status < 500
      return 'Internal Server Error'
    end

    # ⚠ 見るのは `status`（モロヘイヤがクライアントへ返す値）。上流の
    # `source_status` ではない——`handle_gateway_error` が別に扱う。
    def client_error?(error)
      return false unless error.respond_to?(:status)
      return HTTPStatus.client_error?(error.status)
    end

    # 上流のエラー包絡をそのままクライアントへ返す (#4480)。
    #
    # モロヘイヤはプロキシなので、上流が返した理由——Misskey の
    # `{"error":{"code":"TOO_MANY_DRAFTS", ...}}`、Mastodon の
    # `{"error":"Validation failed: ..."}`——を素通しするのが本来の姿。
    # ここに文言テーブルを持つ必要はない。従来は `Ginseng::HTTP` が上流ボディを
    # 捨てて `"Bad response NNN"` に潰していたため、クライアント（capsicum）は
    # 理由で出し分けられなかった（pooza/capsicum#879 / #4380）。
    #
    # ⚠ 透過するのは **上流が JSON として返したものだけ**。`source_body` は
    # HTML エラーページ（nginx の 502 等）や巨大ボディで nil を返すので、
    # その場合は従来どおり `{error: e.message}` に倒れる。モロヘイヤ内部の
    # 例外メッセージを混ぜてはいけない（内部情報の露出）。
    #
    # silent_statuses / silent_codes は Sentry alert を抑止する条件。401 は
    # トークン期限切れで頻繁に起きるため既定で含める。silent_codes は上流の
    # エラーコード（Misskey の `error.code`）で、ユーザー起因の失敗まで
    # Sentry イベントを立てないための口。
    def handle_gateway_error(error, silent_statuses: [401], silent_codes: [])
      # ⚠⚠ **抑止を無条件に外す型がある (#4631)。**モロヘイヤ自身の `fetch_status`
      # 等が落ちているのはクライアント起因ではないので、`silent_statuses` に 404 が
      # 入っていても抑止してはいけない。抑止すると「ALT 編集が全ユーザーで
      # 壊れている」が syslog 1 行に消える。
      # ⚠ 判定はクラスの列挙ではなくマーカーメソッドで行う (#4657)。
      silent = !never_silent?(error) &&
        (silent_statuses.include?(error.source_status) ||
          silent_codes.include?(upstream_error_code(error)))
      # ⚠ 抑止するのは Sentry だけ。silent でも syslog には残す。完全に無音だと
      # 「上流の仕様変更で全投稿が弾かれる」ような事故の頻度・偏りを追えない。
      silent ? error.log : error.alert
      # ⚠ 透過してよいのは**自分の上流**が返したものだけ (#4537)。引用元の他人の
      # サーバー由来 (ForeignGatewayError) は、ステータスもボディも返さず 502 +
      # 自前の文言に倒す。他人のサーバーの応答を返すと、クライアントからは
      # 「モロヘイヤの上流がそう言っている」ように読めてしまう。
      #
      # ⚠⚠ **内部読みの失敗 (InternalGatewayError) も同じ扱い (#4631)。**
      # 上流の 404 をそのまま返すと、クライアントには「その投稿は無い」と読める。
      # 実際に無いのではなく**モロヘイヤ側の読みが失敗した**ので、502 + 自前の
      # 文言に倒して**取り違えを防ぐ**。
      # ⚠ 由来が増えても `WrappedGatewayError` を継げば自動で拒まれる (#4657)。
      if error.is_a?(WrappedGatewayError)
        # ⚠ **クライアントへ返すのは `client_message` (#4657)。**`message` には
        # 内部メソッド名と上流ステータスが入る型がある（ログ側には残る）。
        @renderer.message = {error: error.client_message}
        return @renderer.status = error.status
      end
      # ⚠ 透過するのは Hash のときだけ。`source_body` は JSON の配列も返しうるが、
      # クライアントは `{"error": ...}` を期待しているので配列を渡すと読めない。
      body = error.source_body
      @renderer.message = body.is_a?(Hash) ? body : {error: error.message}
      return @renderer.status = error.source_status
    end

    # ⚠ 素の `Ginseng::GatewayError` は `never_silent?` を持たない。
    # `respond_to?` で見るのは、包み直していない上流エラーを既定（抑止しうる）
    # 側へ倒すため。
    def never_silent?(error)
      return error.respond_to?(:never_silent?) && error.never_silent?
    end

    # 上流の `{"error": {"code": "..."}}` から code を取る。取れなければ nil。
    #
    # ⚠ Mastodon の包絡は `{"error": "Validation failed: ..."}` で error が
    # **文字列**。Hash 前提で dig すると TypeError になる。上流の形を決め打ち
    # できないので、各段で型を確かめる。
    def upstream_error_code(error)
      body = error.source_body
      return nil unless body.is_a?(Hash)
      envelope = body['error']
      return nil unless envelope.is_a?(Hash)
      return envelope['code']
    end
  end
end
