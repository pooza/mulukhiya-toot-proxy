require 'sinatra/base'

module Mulukhiya
  class Controller < Sinatra::Base
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    # 投稿本文系フィールドを info ログに平文で残さない (#4394)。処理には素の
    # @params を使うため、ログ用の複製だけ top-level の該当キーをマスクする。
    SCRUBBED_LOG_PARAMS = [
      'status', 'text', 'body', 'comment', 'spoiler_text', 'cw',
      'q', 'title', 'artist', 'album', # word/suggest・nowplaying のユーザー入力 (#4394)
      'code', # OAuth 認可コード (spotify/auth・annict/auth)。短命だが資格情報なので伏せる
      # ⚠ アクセストークン本体。`i` は Misskey がボディで渡す（MisskeyController#token
      #   のフォールバック）。/logger/mask_query_params は URL のクエリにしか効かない
      #   ので、ボディ側はここで落とす。両方揃って #4511 の掃討が完成する。
      'i', 'access_token'
    ].freeze

    # 上流へそのまま中継してよい受信ヘッダ (#4598)。
    #
    # ⚠ **`@headers` の丸投げはしない。**`Host` / `Content-Length` / `Cookie` /
    # `X-Mulukhiya` まで混ざる。転送してよいものだけを 1 本の許可リストに置く。
    FORWARDED_HEADERS = ['Idempotency-Key'].freeze

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
      rescue StandardError
        @params = Sinatra::IndifferentHash[params]
      end
      logger.info(request: {
        method: request.request_method,
        path: request.path,
        params: scrub_log_params(@params),
        remote: request.ip,
      })
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = token
    rescue => e
      e.log
      @sns&.token = nil
    end

    after do
      status @renderer.status
      content_type @renderer.type
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      @renderer = default_renderer_class.new
      if e.is_a?(Ginseng::Error)
        @renderer.status = e.status
        @renderer.message = e.to_h.except(:backtrace).merge(error: e.message)
        e.alert
      else
        @renderer.status = 500
        @renderer.message = {error: 'Internal Server Error'}
        e.log(path: request.path)
        Sentry.capture_exception(e) rescue nil if Sentry.initialized?
      end
      return @renderer.to_s
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

    def verify_token_integrity!
      expected = token
      return unless expected
      return if sns.token == expected
      logger.error(
        event: 'token_mismatch',
        expected: expected.first(8),
        actual: sns.token&.first(8),
        path: request.path,
      )
      raise Ginseng::AuthError, 'Token integrity check failed'
    end

    # クライアント起因の失敗を Sentry alert に上げない共通判定
    # (#4542 / #4594 / #4603 / #4629)。
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
    # ⚠ **`status` を持たない例外は alert 側へ倒す。**素の `StandardError`
    # （`NoMethodError` 等）はモロヘイヤ自身のバグなので、黙らせてはいけない。
    def report_error(error)
      client_error?(error) ? error.log : error.alert
    end

    def client_error?(error)
      return false unless error.respond_to?(:status)
      return error.status.to_i.between?(400, 499)
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
      # ⚠⚠ **内部読みの失敗は無条件に alert する (#4631)。**モロヘイヤ自身の
      # `fetch_status` 等が落ちているのはクライアント起因ではないので、
      # `silent_statuses` に 404 が入っていても抑止してはいけない。
      # 抑止すると「ALT 編集が全ユーザーで壊れている」が syslog 1 行に消える。
      silent = !error.is_a?(InternalGatewayError) &&
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
      if error.is_a?(ForeignGatewayError) || error.is_a?(InternalGatewayError)
        @renderer.message = {error: error.message}
        return @renderer.status = error.status
      end
      # ⚠ 透過するのは Hash のときだけ。`source_body` は JSON の配列も返しうるが、
      # クライアントは `{"error": ...}` を期待しているので配列を渡すと読めない。
      body = error.source_body
      @renderer.message = body.is_a?(Hash) ? body : {error: error.message}
      return @renderer.status = error.source_status
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
        path: request.path,
      )
    end

    private

    def scrub_log_params(params)
      scrubbed = params.deep_dup
      SCRUBBED_LOG_PARAMS.each do |key|
        scrubbed[key] = '[FILTERED]' if scrubbed.key?(key)
      end
      return scrubbed
    end

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
