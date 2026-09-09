module Mulukhiya
  class WebhookController < Controller
    post '/admin' do
      raise ServiceUnavailableError, 'Info agent not configured' unless info_agent_service
      verify_admin_webhook!(@body)
      admin_payload = JSON.parse(@body)
      event = detect_admin_event(admin_payload)
      raise Ginseng::NotFoundError, 'Unknown event' unless event
      reporter = Event.new(event, {sns: info_agent_service}).dispatch(admin_payload)
      @renderer.message = reporter.to_h
      return @renderer.to_s
    rescue => e
      # ⚠ **ここは `report_error` に寄せない (#4603)。**主な失敗は署名検証
      # (`AuthError`) と設定不備 (`ServiceUnavailableError`・503) で、**署名不一致を
      # 黙らせたくない**。4xx でも alert するのが正しい。
      e.alert
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/:digest' do
      verify_webhook!
      if payload.errors.present?
        @renderer.status = 422
        @renderer.message = payload.errors
      else
        reporter = webhook.post(payload, {headers: forwarded_headers})
        @renderer.message = webhook_response_body(reporter)
        @renderer.status = reporter.response.code
      end
      return @renderer.to_s
    rescue => e
      # ⚠ **消された・打ち間違えた webhook URL を叩かれただけ**で 404 になる
      # (#4603)。同じ `verify_webhook!` を通す `get '/:digest'` は `e.log` なので、
      # **同じ例外が GET なら静か・POST なら alert** という非対称になっていた。
      report_error(e)
      # ⚠ **`status` を持たない例外はここには来ない。**ginseng-core の refine が
      # `StandardError#status` に 500 を定義しているため、引き当ての失敗
      # (`Sequel::DatabaseConnectionError` 等) も 500 を返す＝ `report_error` の
      # alert 側へ倒れる。`respond_to?` は refine が外れたときの保険。
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/:digest' do
      verify_webhook!
      @renderer.message = {message: 'OK'}
      return @renderer.to_s
    rescue => e
      # ⚠ **POST と同じ判定にする** (#4603)。従来は一律 `e.log` で、未知の digest も
      # DB 障害も等しく無音だった。ここも `report_error` に寄せると、4xx は静かなまま
      # **引き当ての失敗だけが alert される**。
      report_error(e)
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def webhook
      # ⚠ **`create` ではなく `create!`** (#4603 の Codex P1)。`create` は DB 障害も
      # 握って nil を返すので、`verify_webhook!` がそれを 404 に変換してしまい、
      # **全 webhook が落ちている状態が「未知の digest」として無音になる**。
      @webhook ||= Webhook.create!(params[:digest])
      return @webhook
    end

    def payload
      @payload ||= SlackWebhookPayload.new(params)
      return @payload
    end

    private

    # 落ちた添付を送信側へ返す (#4649)。
    #
    # ⚠⚠ **`WebhookImageHandler` は per-attachment の `rescue` で失敗を握る。**
    # 「1 枚落ちても投稿は通す」意図として正しいが、**上流の status entity を
    # そのまま返していたので 200 と作成済み投稿 ID が返るだけ**で、送信側は
    # 成功と区別できなかった（運用者は syslog で気づけるが送信側は気づけない）。
    #
    # ⚠ **上流の entity を壊さない。**追加キー 1 つだけを足すので、未知のキーを
    # 無視する既存クライアント（capsicum / tomato-shrieker）は壊れない。
    # ⚠ **落ちた添付が無ければキー自体を足さない**（常時付けると entity の形が
    # 常に変わる）。契約は `docs/api.md` の「Webhook」節が正本。
    def webhook_response_body(reporter)
      body = reporter.response.parsed_response
      # ⚠ 上流が Hash 以外（配列・文字列・エラーページ）を返すことがある。
      # その形に追加キーは足せないので素通しする。
      return body unless body.is_a?(Hash)
      entity = mulukhiya_entity(reporter, body)
      return body if entity.empty?
      return body.merge('mulukhiya' => entity)
    end

    def mulukhiya_entity(reporter, body)
      entity = {}
      errors = attachment_errors(reporter)
      missing = missing_attachment_count(reporter, body)
      entity['attachment_errors'] = errors if errors.present?
      entity['missing_attachments'] = missing if missing.positive?
      return entity
    end

    # ⚠⚠ **「落ちなかった」を上流の応答で裏づける（PR #4684 の Codex P1）。**
    # `Idempotency-Key` を付けた再送では、上流（Mastodon）が**初回のキャッシュ済み
    # 投稿**を返す。このリクエストのアップロードが成功して `errors` が空でも、
    # **返ってくる投稿にはその添付が載っていない**ので、`mulukhiya` キーを落とすと
    # **「全部通った」と嘘をつく**ことになる。渡した本数と応答の本数を突き合わせる。
    #
    # ⚠ **分からないときは 0 を返す**（黙って「欠けている」と言わない）。渡した本数を
    # 控えていない経路と、応答の形が未知の場合が該当する。
    def missing_attachment_count(reporter, body)
      sent = reporter.temp[:attachment_count]
      return 0 unless sent.is_a?(Integer)
      returned = response_attachment_count(body)
      return 0 unless returned.is_a?(Integer)
      return [sent - returned, 0].max
    end

    # 上流が返した投稿の添付本数。
    #
    # ⚠⚠ **Misskey は `createdNote.files`**（トップレベルの `files` ではない）。
    # トップレベルを読むと常に見つからず、**毎回「全部欠けている」と誤判定する**
    # （`docs/api.md` の「応答の添付配列」と同じ罠）。
    def response_attachment_count(body)
      attachments = body['media_attachments'] || body.dig('createdNote', 'files')
      return attachments.is_a?(Array) ? attachments.size : nil
    end

    # ⚠ **添付に紐づく失敗だけを返す。**`reporter.errors` にはハンドラの
    # タイムアウト等も混ざるが、それらは送信側が対処できる情報ではない。
    # `attachment` を持つ entry ＝ `WebhookImageHandler#record_drop` の分だけ拾う。
    #
    # ⚠ **`attachment` は `scrub_log_params` を通した後のもの。**`image_url` は
    # `SCRUBBED_LOG_PARAMS` に無いので原文のまま＝送信側が自分で送った URL と
    # 突き合わせられる。⚠ **本文系（`title` / `text` 等）は `[FILTERED]` なので、
    # 添付を丸ごと返さず `url` と `message` だけにする**（#4630 で塞いだ穴を
    # レスポンス側で開け直さない）。
    def attachment_errors(reporter)
      return reporter.errors.filter_map do |error|
        next unless error.is_a?(Hash)
        attachment = error[:attachment] || error['attachment']
        next unless attachment.is_a?(Hash)
        # ⚠ **`url` が nil になる回がある (#4694)。**`SlackWebhookPayload` は
        # `blocks` の `type: image` を `image_url` の有無を見ずに images へ積むので、
        # `image_url` を持たない image ブロックがここまで来る。
        # `docs/api.md` は `url` を string と書いているので、**キーごと落とす**
        # （null を返して契約を破らない）。
        entry = {'message' => error[:message] || error['message']}
        url = attachment['image_url']
        entry['url'] = url if url.is_a?(String) && url.present?
        entry
      end
    end

    def verify_webhook!
      raise ServiceUnavailableError, 'Webhook is not enabled' unless controller_class.webhook?
      return if webhook
      raise Ginseng::NotFoundError,
        "Webhook not found (digest: #{params[:digest][0, 12]}...)"
    end

    def verify_admin_webhook!(raw_body)
      secret = config['/agent/info/webhook/secret']
      raise Ginseng::AuthError, 'Webhook secret not configured' unless secret
      if (signature = request.env['HTTP_X_HUB_SIGNATURE'])
        expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"
        unless Rack::Utils.secure_compare(signature, expected)
          raise Ginseng::AuthError, 'Invalid signature'
        end
      elsif (hook_secret = request.env['HTTP_X_MISSKEY_HOOK_SECRET'])
        unless Rack::Utils.secure_compare(hook_secret, secret)
          raise Ginseng::AuthError, 'Invalid secret'
        end
      else
        raise Ginseng::AuthError, 'Missing webhook signature'
      end
    end

    def detect_admin_event(payload)
      return :user_approved if payload['event'] == 'account.approved'
      return :user_approved if payload['type'] == 'userCreated'
      return nil
    end
  end
end
