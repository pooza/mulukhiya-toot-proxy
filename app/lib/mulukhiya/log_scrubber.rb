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
