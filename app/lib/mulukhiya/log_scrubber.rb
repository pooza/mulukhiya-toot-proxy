module Mulukhiya
  # 投稿本文系フィールドと資格情報をログに平文で残さない (#4394 / #4630)。
  #
  # ⚠⚠ **Controller だけの関心事ではない。**5.35.0 のリリース前レビューで、
  # `WebhookImageHandler#drop_attachment` が落とした添付を丸ごと `logger.error`
  # へ渡し、**同じリリースで塞いだはずの Slack legacy attachments の本文
  # （`title` / `text` / `pretext` / `footer` / `author_name` / `fields[].value`）を
  # 平文で出し直していた**ことが判明したため、Controller から切り出して
  # 共有できるようにした。
  #
  # ⚠ **gem 側の `Ginseng::Logger#mask` では落ちない。**あちらが見るのは
  # `/logger/mask_fields`（`auth` / `endpoint` / `password` / `publickey` /
  # `secret` / `token`）だけで、本文系は 1 つも入っていない。`mask_url` も
  # **URL のクエリパラメータの値**しか伏せないので、URL 全体や本文には効かない。
  module LogScrubber
    SCRUBBED_LOG_PARAMS = [
      'status', 'text', 'body', 'comment', 'spoiler_text', 'cw',
      'q', 'title', 'artist', 'album', # word/suggest・nowplaying のユーザー入力 (#4394)
      # ⚠ Slack legacy attachments の本文系 (#4630)。`SlackWebhookPayload#format_attachment`
      #   が **すべて投稿本文へ組み立てる**ので、`text` だけ伏せても残りが平文で残る。
      #   `title` は上の行で既に対象。`fields[].value` はキー名が `value`。
      'pretext', 'author_name', 'value', 'footer',
      'code', # OAuth 認可コード (spotify/auth・annict/auth)。短命だが資格情報なので伏せる
      # ⚠ アクセストークン本体。`i` は Misskey がボディで渡す（MisskeyController#token
      #   のフォールバック）。/logger/mask_query_params は URL のクエリにしか効かない
      #   ので、ボディ側はここで落とす。両方揃って #4511 の掃討が完成する。
      'i', 'access_token'
    ].freeze

    # ⚠⚠ **webhook の digest は資格情報そのもの (#4655)。**
    # `POST /mulukhiya/webhook/<digest>` は **digest だけで投稿権限が通る**
    # （`verify_webhook!` 以外に認証が無い）。⚠ **既存の掃討はどれも当たらない** —
    # `Ginseng::Logger#mask_url` は `\A<scheme>://` に一致する**値**にしか効かず、
    # `SCRUBBED_LOG_PARAMS` は**パラメータのキー**しか見ず、nginx 側のパターン
    # （#4511 の `access_token=` / `"i":"` / `[?&]i=`）にも当たらない。
    # **webhook を 1 回使うたびに完全な鍵が syslog に残っていた。**
    #
    # ⚠⚠ **マウント位置ではなく digest の形で判定する。**webhook のパスは
    # `config/route.yaml` で変えられるし、テストでは各 Controller が root に載る。
    # **接頭辞で切ると、設定を変えた瞬間に黙って秘匿が外れる**（fail-open）。
    # `Webhook.create_digest` は `String#sha256`＝ **64 桁の 16 進**なので、
    # 経路上でこの形を持つのは digest だけ。
    WEBHOOK_DIGEST_PATTERN = /\A[0-9a-f]{64}\z/i

    # digest として残す先頭の文字数。⚠ `verify_webhook!` のエラーメッセージ
    # （`"Webhook not found (digest: #{params[:digest][0, 12]}...)"`）と揃える。
    # **同じ digest がログとエラーで別の形に見えると突き合わせられない。**
    LOG_DIGEST_PREFIX_LENGTH = 12

    # `scrub_log_params` が潜る深さの上限 (#4630)。Block Kit の
    # `blocks[].text.text` で 4、`attachments[].blocks[].text.text` で 6 なので、
    # 実用形には十分な余裕がある。
    MAX_LOG_SCRUB_DEPTH = 12

    # ⚠⚠ **入れ子まで走査する (#4630)。**Slack 互換 webhook が実際に使う
    # Block Kit の本文は `blocks` / `attachments` の入れ子の中にある。
    #
    #   {"blocks":[{"type":"section","text":{"text":"（本文）"}}]}
    #
    # ⚠ **同じ本文を `text` で送れば `[FILTERED]` になるのに、`blocks` で送ると
    # 平文で syslog に残る**＝送り方で秘匿の効き方が変わっていた。
    def scrub_log_params(params)
      return scrub_log_value(params.deep_dup, 0)
    end

    # パスに埋まった webhook の digest を丸める (#4655)。
    #
    # ⚠ **パスの構造は仮定しない。**セグメントに割って、digest の形をしたものだけを
    # 丸める。前後にどんなセグメントが付いていても効く。
    def scrub_log_path(path)
      return path unless path.is_a?(String)
      return path.split('/', -1).map {|segment| scrub_log_digest(segment)}.join('/')
    end

    # digest 単体を丸める。⚠ **digest でない値は 1 バイトも変えない**
    # （ログが役に立たなくなる）。
    #
    # ⚠⚠ **パーセントエンコードを解いてからも見る (#4655・PR #4664 の Codex P1)。**
    # `request.path` は**生のまま**（`PATH_INFO` そのもの）で、Sinatra の
    # `params[:digest]` だけがデコード済み。つまり `%61` を 1 文字混ぜるだけで
    #
    #   - `Webhook.create!` は**デコード後の正しい digest で引き当てに成功**する
    #   - ⚠ ログに載る `request.path` は `%61…` のままで 64 桁の 16 進に一致しない
    #
    # となり、**可逆な形の完全な鍵がそのまま syslog に残っていた**（実測で確認）。
    def scrub_log_digest(value)
      return value unless value.is_a?(String)
      return "#{value[0, LOG_DIGEST_PREFIX_LENGTH]}..." if value.match?(WEBHOOK_DIGEST_PATTERN)
      decoded = unescape_log_segment(value)
      return value unless decoded.match?(WEBHOOK_DIGEST_PATTERN)
      # ⚠ **残す 12 文字はデコード後のもの。**`verify_webhook!` のエラーメッセージは
      # `params[:digest]`（デコード済み）から作るので、生の側を切ると突き合わせられない。
      return "#{decoded[0, LOG_DIGEST_PREFIX_LENGTH]}..."
    end

    # ⚠ **デコードできなくても落とさない。**ここで例外を上げるとログ行そのものが
    # 消える。⚠ 解けない値は Sinatra 側でも解けない＝ `Webhook.create!` が
    # 引き当てられないので、**その形で有効な鍵が漏れることはない**。
    def unescape_log_segment(value)
      return Rack::Utils.unescape_path(value)
    rescue StandardError
      return value
    end

    # ⚠ **深さで打ち切る。**外部から渡る JSON なので、際限なく潜ると
    # スタックを掘り尽くせる。打ち切りは**残す側ではなく落とす側**へ倒す
    # （読めない深さのものを平文で通すより、伏せて出すほうが安全）。
    def scrub_log_value(value, depth)
      return '[FILTERED]' if depth > MAX_LOG_SCRUB_DEPTH
      case value
      when Hash
        value.each_key do |key|
          value[key] = if SCRUBBED_LOG_PARAMS.include?(key.to_s)
            '[FILTERED]'
          else
            scrub_log_value(value[key], depth + 1)
          end
        end
      when Array
        value.map! {|v| scrub_log_value(v, depth + 1)}
      end
      return value
    end
  end
end
