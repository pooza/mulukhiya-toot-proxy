require 'sinatra/base'

module Mulukhiya
  class Controller < Sinatra::Base
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    include LogScrubber
    include ControllerErrorMethods
    include UpstreamErrorMethods

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
      rescue StandardError => e
        # ⚠⚠ **ここは黙って body を捨てる経路 (#4699)。**フォーム POST や空 body でも
        # 通るので rescue 自体は正しいが、**JSON のつもりで送られた body が落ちた**ときも
        # 同じ穴に落ちる。クライアントからは「投稿したのに内容が空」に見え、
        # ログに手掛かりが 1 行も残らない。
        #
        # ⚠ **JSON らしい body のときだけ残す。**毎リクエスト出すとフォーム POST で
        # syslog が埋まる（#4549 の型）。
        #
        # ⚠ **ここの `JSON.parse` は json gem ではなく Yajl**（ginseng-core が引く
        # `yajl/json_gem` が差し替えている・#4699）。json 3.0 の `allow_duplicate_key`
        # の既定変更は**この経路には届かない**（重複キーは今も後勝ち）。
        log_unparsable_body(e)
        @params = Sinatra::IndifferentHash[params]
      end
      reject_invalid_encoding!
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
      # ⚠ **Content-Type も合わせ直す (#4725)。**ルートが返した 404 では `after` が
      # この block より**先に**走っている（Sinatra はルートが返った後で
      # `error_block!(response.status)` を呼ぶ）。レンダラだけ差し替えると、
      # RSS / HTML のルートで**ヘッダはフィード・本文は JSON**になって食い違う。
      content_type @renderer.type
      return @renderer.to_s
    end

    error do |e|
      @renderer = default_renderer_class.new
      if e.is_a?(Ginseng::Error)
        @renderer.status = e.status
        @renderer.message = e.to_h.except(:backtrace).merge(error: e.message)
        headers('Retry-After' => e.retry_after.to_s) if e.is_a?(ConflictError) && e.retry_after
      else
        @renderer.status = 500
        @renderer.message = {error: 'Internal Server Error'}
      end
      # ⚠ **ここは最後の受け皿で、どのルートから来たか分からない (#4654)。**
      # 判断材料はステータスしか無いので `report_error` に寄せる。従来は
      # 無条件 `e.alert` で、ルートのローカル rescue をすり抜けた 4xx——
      # `not_found` を通らない `AuthError` 等——まで Sentry と Event(:alert) に
      # 落ちていた。⚠ **4 系統目**（#4542 / #4594 / #4603 / #4629）。
      #
      # ⚠ **Ginseng 以外の例外も同じ (#4724)。**従来はそちらだけ `e.log` ＋
      # `Sentry.capture_exception` の直書きで、`Event(:alert)` にもデッドマンにも
      # 乗っていなかった。ここに落ちるのはモロヘイヤ自身のバグ（`NoMethodError` 等）が
      # 主なので、Sentry だけでなく通知まで届かないと気づけない。
      report_error(e)
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
    # ⚠⚠ **アプリ内の `JSON.parse` は Yajl** で、Yajl のメッセージも **2 行目に入力を
    # そのまま含む**（ASCII-8BIT なので日本語の正規表現では見つからない・#4699）。
    # どちらも利用者由来の値なので、`message` を出した時点で「本文は出さない」が破れる（#4394 / #4630）。
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

    # 不正な UTF-8 バイト列を含むリクエストは、入口で 400 を返して終える (#4600)。
    #
    # 🔴 **Rack のフォームのパースは、壊れたバイト列を弾かない。**UTF-8 のタグが付いたまま
    # 通るので、奥の `TootParser#tags` などで `ArgumentError` になり、クライアントのバグ
    # （切れたマルチバイト等）が 500 ＋ Sentry に化けていた。
    # 🔴 **JSON の本文は逆に、パーサ（Yajl）が弾いて本文ごと捨てられる。**`before` の rescue が
    # フォームの params へ倒すので、クライアントからは「投稿したのに内容が空」になる。
    # こちらも同じ 400 で返す（実測: `lexical error: invalid bytes in UTF8 string`）。
    # ⚠⚠ ログで伏せないキー（ALT の `description` など）に来ると、リクエストログの `to_json` が
    # 先に落ち、`before` の rescue がトークンを外して **401（token_mismatch）に化ける。**
    # ＝ **リクエストログより前に見ること。**
    #
    # ⚠ **`scrub` で直さない。**`"\xE3\x81ほげ".scrub` は `"�ほげ"` になり、化けた内容のまま
    # 投稿される。入力が壊れていることはクライアントへ返す情報。
    # ⚠ クライアント起因なので Sentry・通知へは出さない（ログ 1 行だけ）。
    # ⚠ `halt` は例外ではないので、`before` の rescue には掛からない。
    def reject_invalid_encoding!
      key = :body if json_request? && !valid_utf8?(@body)
      key ||= invalid_encoding_key(@params)
      return unless key
      logger.error(
        error: 'request contains invalid byte sequence',
        key: key.to_s.scrub('?'),
        path: scrub_log_path(request.path),
      )
      @renderer.status = 400
      @renderer.message = {error: 'リクエストに不正な UTF-8 バイト列が含まれています。'}
      halt @renderer.to_s
    end

    # UTF-8 として正しいか。
    #
    # ⚠⚠ **付いているタグを信用しない（PR #4810 の Codex P2）。**multipart の文字列は
    # パートが名乗った charset で、知らない charset なら `ASCII-8BIT` でタグ付けされる。
    # `ASCII-8BIT` の `valid_encoding?` は常に true なので、そのまま見ると壊れたバイト列が
    # 素通りし、リクエストログの `to_json` で落ちる（＝ 401 に化ける経路が残る）。
    # 奥の処理は全部 UTF-8 を前提にしているので、UTF-8 として読めるかで見る。
    def valid_utf8?(value)
      return value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    # 本文全体を JSON として検査する要求か。
    #
    # ⚠ **先頭の 1 文字だけで決めない（PR #4810 の Codex P2）。**壊れたバイトが `{` の前に
    # あると `json_body?` が偽になり、本文が捨てられたまま奥へ進む。メディアタイプでも見る。
    def json_request?
      return true if json_body?
      return request.media_type.to_s.match?(%r{\Aapplication/(.+\+)?json\z}i)
    end

    # 壊れた文字列を持つ最初のキーを返す（無ければ nil）。入れ子の Hash / Array も辿る。
    #
    # ⚠ アップロードの `tempfile` など String 以外は見ない（中身はバイナリで正しい）。
    def invalid_encoding_key(value, key = :body)
      case value
      when String
        return key unless valid_utf8?(value)
      when Array
        return value.filter_map {|v| invalid_encoding_key(v, key)}.first
      when Hash
        return value.filter_map do |k, v|
          valid_utf8?(k.to_s) ? invalid_encoding_key(v, k) : k
        end.first
      end
      return nil
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
    #
    # ⚠ **判定は SNS の型で行う (#4635)。**コントローラ名で見ると、専用の
    # コントローラクラスを持たない Mastodon 系（Akkoma・Fedibird）で
    # `controller_class` が nil になって落ちる（webhook 経路も通る）。
    def forwarded_headers
      return {} unless Environment.mastodon_type?
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

    # 取り込みを止めた形式を、**上流へ投げる前に**断る (#4733 / #4734)。
    #
    # ⚠⚠ **これが無いと、クライアント起因の入力で 500 とアラートが出る。**
    # `setup_vips` の許可リストに入っていない形式は `ImageFile#type` の `rescue` に
    # 飲まれて `image?` が false になり、**ハンドラが黙って素通し**する。上流へ届いた
    # HEIC を Mastodon 4.7.2 も `Vips.block` で弾くが、Paperclip がそれを
    # `Paperclip::Error` → **HTTP 500** に変換する（harness の 4.7.2 で実測）。
    # その 500 は `handle_upload_gateway_error` → `handle_gateway_error` で
    # 🔴 **`error.alert` を直接呼ぶ**（`report_error` の `throttled_alert` を経由しない）
    # ので、**1 アップロード = 1 アラート**で slack / line / mail が同期で回る。
    # 2026-08-17 にアラートメールが大量発生したのと同じ経路（pooza/chubo2#179 / #4594）。
    #
    # ⚠ **判定に vips を使わない。**`ImageFile#type` は `Vips::Image.new_from_file` を
    # 呼ぶので、止めたい相手をデコードしてしまい本末転倒になる。`MediaFile#type` は
    # Marcel ＝ **マジックバイトだけ**で `image/heic` を返す（実測）。
    #
    # ⚠ 422 は Mastodon が受け付けない形式に返すのと同じステータス
    # （`Validation failed: File content type is invalid`）なので、クライアントは既に扱える。
    # `Ginseng::ValidateError` は 4xx なので `report_error` が log 止めにする＝アラートは鳴らない。
    #
    # ⚠ **解除条件は #4733 と同じ**: `libheif >= 1.23.4` が pkg / ports に来たら
    # `Mulukhiya::VIPS_ALLOWED_OPERATIONS` と一緒にここも戻す。
    BLOCKED_UPLOAD_TYPES = ['image/heic', 'image/heif'].freeze

    def verify_upload_type!(field = :file)
      path = params.dig(field, :tempfile)&.path
      return unless path
      type = MediaFile.new(path).type
      return unless BLOCKED_UPLOAD_TYPES.member?(type)
      raise Ginseng::ValidateError,
        'HEIF 形式（.heic / .heif）の画像は、セキュリティ上の理由で現在受け付けていません。' \
          'JPEG・PNG・WebP のいずれかで保存し直してからお試しください。'
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
      # 再発検知がここに掛かっている。`AuthError` は 403 なので既定では log 止めになる。
      raise NeverSilent.mark(Ginseng::AuthError.new('Token integrity check failed'))
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
