require 'sinatra/base'

module Mulukhiya
  class Controller < Sinatra::Base
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    include LogScrubber

    # 上流へそのまま中継してよい受信ヘッダ (#4598)。
    #
    # ⚠ **`@headers` の丸投げはしない。**`Host` / `Content-Length` / `Cookie` /
    # `X-Mulukhiya` まで混ざる。転送してよいものだけを 1 本の許可リストに置く。
    FORWARDED_HEADERS = ['Idempotency-Key'].freeze

    # サーバー側の失敗を鳴らす間隔 (秒) と、その印を置く Redis キーの接頭辞 (#4693)。
    # ⚠ 型ごとに独立して数える。`Sequel::DatabaseConnectionError` の連打を抑えている間に
    # 別の型（本物のバグ）が出たら、そちらは 1 回目として鳴ってほしい。
    ALERT_THROTTLE_SECONDS = 300
    ALERT_THROTTLE_KEY_PREFIX = 'alert_throttle'.freeze

    set :root, Environment.dir
    enable :method_override

    before do
      @renderer = default_renderer_class.new
      @body = request.body.read.to_s
      @headers = request.env.select {|k, _v| k.start_with?('HTTP_')}.transform_keys do |k|
        k.sub(/^HTTP_/, '').downcase.gsub(/(^|_)\w/, &:upcase).tr('_', '-')
      end
      begin
        @params = Sinatra::IndifferentHash[JSON.parse(@body)]
      rescue StandardError => e
        # ⚠⚠ **ここは黙って body を捨てる経路 (#4699)。**フォーム POST や空 body でも
        # 通るので rescue 自体は正しいが、**JSON のつもりで送られた body が落ちた**ときも
        # 同じ穴に落ちる。クライアントからは「投稿したのに内容が空」に見え、
        # ログに手掛かりが 1 行も残らない。
        #
        # ⚠ **JSON らしい body のときだけ残す。**毎リクエスト出すとフォーム POST で
        # syslog が埋まる（#4549 の型）。
        #
        # 🔴 **json 3.0 へ上げる前の前提。**3.0 は `allow_duplicate_key` の既定が
        # false になるので、**いままで「後勝ち」で通っていた重複キーの body が
        # 丸ごとここへ落ちる**。無音のままだと版を上げた影響を切り分けられない。
        log_unparsable_body(e)
        @params = Sinatra::IndifferentHash[params]
      end
      logger.info(request: {
        method: request.request_method,
        # ⚠ **パスも秘匿の対象 (#4655)。**webhook の digest はそれ 1 つで
        # 投稿権限が通るので、パスをそのまま出すと使うたびに鍵がログに残る。
        path: scrub_log_path(request.path),
        params: scrub_log_params(@params),
        remote: request.ip,
      })
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = token
    rescue => e
      # ⚠ **ここが黙ると原因の分からない 500 だけが残る (#4654)。**`before` の
      # 失敗は Redis / Postgres 障害（`sns_class.new` / トークン引き当て）が主で、
      # 従来は一律 `e.log` ＝ Sentry に何も出なかった。
      report_error(e)
      @sns&.token = nil
    end

    after do
      status @renderer.status
      content_type @renderer.type
    end

    not_found do
      # ⚠⚠ **ルート側が既に body を作っていたら差し替えない (#4520)。**
      # Sinatra は `response.status == 404` を見て、**ルートが正常に返った後でも**
      # この block を呼ぶ（`invoke { error_block!(response.status) }`）。そのため
      # ルートの `rescue` が組み立てた `{error: e.message}` が毎回この既定メッセージで
      # 上書きされ、**404 だけボディの形が違って**いた。
      #
      # 🔴 影響は「見た目が違う」では済まない。403/422/5xx は `error` / `errors` キーを
      # 持つのに 404 だけ `{package, class, message}` になるので、**クライアントが
      # キーの有無で分岐できない**。404 の理由（投稿が無い / 他人の投稿 / 機能が無効）も
      # 全部同じ body に潰れていた。
      #
      # ⚠ **ルート未一致と区別できる。**`before` が毎回 `default_renderer_class.new` を
      # 置くが、`message` は nil のままなので、埋まっているのは**ルートが書いたとき
      # だけ**。⚠ `respond_to?` を見るのは、ルートが message を持たない
      # レンダラ（フィード・生ファイル）へ差し替えていることがあるため。
      #
      # ⚠⚠ **判定は `present?` ではなく `nil?`（PR #4707 の Codex P2）。**上流が 404 と
      # **空の JSON ボディ `{}`** を返すと `handle_gateway_error` が `{}` を `message` へ
      # 入れるが、`{}.present?` は false なので `present?` だと**上流の応答をここで
      # 潰してしまう**。`api.md` が約束している「上流の包絡をそのまま透過する」に反する。
      # **未設定は nil だけ**なので `nil?` で足りる。
      return @renderer.to_s if @renderer.respond_to?(:message) && !@renderer.message.nil?

      @renderer = default_renderer_class.new
      @renderer.status = 404
      # ⚠ **ここは `scrub_log_path` を通さない (#4655)。**これはログではなく
      # **要求した本人へ返すボディ**で、パスは相手が送ってきた値そのもの。
      # 丸めても秘匿にはならず、404 のボディ（api.md の契約）が変わるだけ。
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      @renderer = default_renderer_class.new
      if e.is_a?(Ginseng::Error)
        @renderer.status = e.status
        @renderer.message = e.to_h.except(:backtrace).merge(error: e.message)
        # ⚠ **ここは最後の受け皿で、どのルートから来たか分からない (#4654)。**
        # 判断材料はステータスしか無いので `report_error` に寄せる。従来は
        # 無条件 `e.alert` で、ルートのローカル rescue をすり抜けた 4xx——
        # `not_found` を通らない `AuthError` 等——まで Sentry と Event(:alert) に
        # 落ちていた。⚠ **4 系統目**（#4542 / #4594 / #4603 / #4629）。
        report_error(e)
      else
        @renderer.status = 500
        @renderer.message = {error: 'Internal Server Error'}
        e.log(path: scrub_log_path(request.path))
        Sentry.capture_exception(e) rescue nil if Sentry.initialized?
      end
      return @renderer.to_s
    end

    # JSON のつもりで送られた body が解釈できなかったことを残す (#4699)。
    #
    # ⚠ **JSON らしい body のときだけ。**`{` / `[` で始まらないものはフォーム POST や
    # 空 body なので、落ちるのが正常。毎回出すと syslog が埋まる。
    # ⚠⚠ **例外メッセージを出さない（PR #4708 の Codex P1）。**
    # `JSON::ParserError` のメッセージは**壊れた入力をそのまま反響する**。実測:
    #
    #   JSON::ParserError: unexpected character: '秘密の本文}' at line 1 column 12
    #   JSON::ParserError: expected ',' or '}' after object value, got: '秘密のトークンabc123}'
    #
    # ⚠ json 3 の重複キーエラーは**キー名そのもの**を含む。どちらも利用者由来の
    # 値なので、`message` を出した時点で「本文は出さない」が破れる（#4394 / #4630）。
    # ⚠ 長さの上限も無いので、**巨大なログ 1 行**にもなりうる。
    #
    # **残すのは型と大きさだけ。**「どこで落ちたか」は class と path で足りる。
    def log_unparsable_body(error)
      return unless json_body?
      logger.error(
        error: 'request body is not parsable as JSON',
        class: error.class.to_s,
        bytesize: @body.bytesize,
        path: scrub_log_path(request.path),
      )
    end

    def json_body?
      return @body.to_s.lstrip.start_with?('{', '[')
    end

    def name
      return self.class.to_s.split('::').last.sub(/Controller$/, '').underscore
    end

    alias underscore name

    def token
      return nil
    end

    def api_version
      return params[:version].sub(/^v/, '').to_i
    end

    # 上流へ中継する受信ヘッダ (#4598)。
    #
    # ⚠ **モロヘイヤ側で生成しない。**付いてこなければ付けずに転送する。本文の
    # ハッシュ等から自前で作ると、実況で意図的に連投される同一本文を上流が
    # 畳んでしまい、**投稿が黙って消える**。
    #
    # ⚠ **`Idempotency-Key` は Mastodon API の仕様**で、Misskey には相当物が無い。
    # 送っても無害だが、「効いているつもり」を作らないために送らない。
    #
    # ⚠ **上流の畳み込みは TTL 1 時間・アカウント単位**（mastodon の
    # `PostStatusService` が `idempotency:status:<account>:<key>` を setex する）。
    # 秒〜分の再送には効くが、それを超える再実行では効かない。
    def forwarded_headers
      return {} unless controller_class.name == 'mastodon'
      return @headers.to_h.slice(*FORWARDED_HEADERS)
    end

    # トークンを暗号化する。⚠ **失敗はこちらの設定の問題 (#4693)。**
    #
    # ⚠⚠ `Ginseng::CryptError#status` は **403** なので、`report_error` の
    # ステータス判定では「クライアントが悪い」側に落ちて **`log` 止め**になる。
    # だが実体は `/crypt/password` の未設定・破損で、**全ユーザーのトークン発行が
    # 403 になるのに Sentry には何も出ない**（`Crypt.password` が `rescue nil` で
    # nil に落ち、`PKCS5.pbkdf2_hmac(nil, ...)` が `CryptError` に包まれる）。
    #
    # ⚠ **クライアントは何も悪くない**ので、ここで印を付けて必ず鳴らす。
    # ⚠ `report_error` 側で例外クラスを列挙しないための形（#4603 / #4629 で
    # 列挙は実際に取りこぼしている）。
    def encrypt_token!(value)
      return value.encrypt
    rescue => e
      raise NeverSilent.mark(e)
    end

    def verify_token_integrity!
      expected = token
      return unless expected
      return if sns.token == expected
      logger.error(
        event: 'token_mismatch',
        expected: expected.first(8),
        actual: sns.token&.first(8),
        path: scrub_log_path(request.path),
      )
      # ⚠⚠ **これは「クライアントが悪い」ではない (#4693)。**リクエスト間で
      # トークンが混線した＝**セキュリティ不変条件の破れ**で、2025-10 のトークン
      # 汚染事故（`Gemfile` が rack / sinatra に上限を書いている理由そのもの）の
      # 再発検知がここに掛かっている。401 なので既定では log 止めになる。
      raise NeverSilent.mark(Ginseng::AuthError.new('Token integrity check failed'))
    end

    # クライアント起因の失敗を Sentry alert に上げない共通判定
    # (#4542 / #4594 / #4603 / #4629 / #4654)。
    #
    # ⚠⚠ **コントローラ層の rescue はここ 1 本に寄せた (#4654)。**最上位の
    # `error` ブロックも含め、`e.log` / `e.alert` / `e.status < 500 ? ... : ...` の
    # 直書きは残さない。**唯一の例外は `WebhookController` の `post /admin`** で、
    # 署名不一致（4xx）を黙らせたくないという理由が現地に書いてある。
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
      # 「401 だがセキュリティ不変条件の破れ」型（`token_mismatch`）が、
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

    # 同じ型の失敗は窓のあいだ 1 回だけ鳴らす (#4693)。
    #
    # ⚠ `StartupNotificationWorker#notify_failure` と同じ「連続失敗の 1 回目だけ」の
    # 考え方だが、**成功で解除する代わりに TTL で解除する。**`before` は毎リクエスト
    # 走るので、成功のたびに Redis を書くと平常時のコストが乗る。
    #
    # ⚠⚠ **カウンタ自体が落ちたら log へ倒す。**ここへ来る主因が Redis 全断なので、
    # 抑止できないからと鳴らす側へ倒すと**まさに避けたいスパムになる**。
    # Redis の死は `/health` の redis 側で観測されるので、二重に鳴らす価値がない
    # （`StartupNotificationWorker` と同じ判断）。
    # ⚠ **厳密な排他ではない。**`Ginseng::Redis::Service#set` は `NX` を取らないので
    # `key?` → `setex` の 2 段になる。同時に来た数本が二重に鳴ることはあるが、
    # **抑えたいのは「全断中に毎リクエスト鳴る」**ほうなので、これで足りる。
    def throttled_alert(error)
      redis = Redis.new
      key = "#{ALERT_THROTTLE_KEY_PREFIX}/#{error.class}"
      return error.log(throttled: true) if redis.key?(key)
      redis.setex(key, ALERT_THROTTLE_SECONDS, 1)
      error.alert
    rescue => e
      error.log(throttle_error: e.class.to_s)
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

    def verify_account_integrity!(response)
      return unless response&.parsed_response.is_a?(Hash)
      posted_id = response.parsed_response.dig('account', 'id') ||
        response.parsed_response.dig('createdNote', 'user', 'id')
      return unless posted_id
      return if posted_id.to_s == sns.account&.id.to_s
      logger.error(
        event: 'account_mismatch_detected',
        expected_account: sns.account&.id,
        posted_as: posted_id,
        path: scrub_log_path(request.path),
      )
    end

    private

    def default_renderer_class
      return Ginseng::Web::JSONRenderer
    end

    def path_prefix
      return '' if Environment.test?
      return "/mulukhiya/#{name}"
    end

    def token_echo_response
      raise Ginseng::NotFoundError, 'Not Found' unless config['/diag/enable']
      t = token
      return {
        token_prefix: t&.first(8),
        token_length: t&.length,
        sns_token_prefix: sns.token&.first(8),
        sns_token_length: sns.token&.length,
        match: t.present? && t == sns.token,
        thread_id: Thread.current.object_id,
        timestamp: Time.now.iso8601(6),
      }
    end
  end
end
