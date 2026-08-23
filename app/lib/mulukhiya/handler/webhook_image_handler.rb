module Mulukhiya
  class WebhookImageHandler < Handler
    def disable?
      return true unless controller_class.webhook?
      return true unless sns.account&.webhook
      return super
    end

    # ⚠ **webhook 経路だけ pinning する (#4576)。**ここは第三者が任意の URL を
    # 送り込める口で、取得したボディがそのままタイムラインへ出る full-read。
    # CDN のローテーションを心配する相手ではないので、DNS リバインディング
    # (#4524) を潰すほうを採る。
    def upload_host_validator
      return RemoteHost.validator
    end

    def handle_pre_webhook(payload, params = {})
      payload.deep_stringify_keys!
      payload[attachment_field] = Concurrent::Array.new(payload[attachment_field] || [])
      slots = create_slots(payload)
      Parallel.each(payload['attachments'] || [], in_threads: Parallel.processor_count) do |a|
        next unless uri = Ginseng::URI.parse(a['image_url'])
        next unless reserve_slot(slots)
        upload_attachment(payload, uri, slots)
      rescue => e
        drop_attachment(e, a)
      end
    end

    private

    # ⚠⚠ **握り潰しても黙って消さない (#4633)。**「1 枚落ちても投稿は通す」設計
    # 自体は正しいが、上限超過 (`/media/download/max_bytes`) も取得失敗も
    # **200 と作成済み投稿 ID が返るだけ**で、送信側は成功と区別できなかった。
    # ⚠ `attachment` ごと渡すのは、`image_url` が値そのものとして
    # `Logger#mask_url` に当たり `[FILTERED]` になるため (#4630)。
    def drop_attachment(error, attachment)
      logger.error(error: 'webhook attachment dropped', reason: error.class.to_s, attachment:)
      errors.push(class: error.class.to_s, message: error.message, attachment:)
    end

    def create_slots(payload)
      return Concurrent::AtomicFixnum.new(
        [sns.max_media_attachments - payload[attachment_field].count, 0].max,
      )
    end

    # ⚠⚠ **判定と確保を不可分にする (#4633)。**従来は
    # `sns.max_media_attachments <= payload[attachment_field].count` を
    # **ダウンロード + アップロードの前**に見ていた。`Concurrent::Array` は `push` を
    # 原子化するが判定は守らないので、上限 4・現在 3 枚で残り 3 件を 3 スレッドが
    # 同時に評価すると **3 本とも `3 < 4` を通過**し、それぞれ数百 ms〜秒かけて
    # アップロードしてから揃って `push` する ＝ **6 枚**。上流が `media_ids` の
    # 上限超過で **422 を返し webhook 投稿ごと落ちる**（かつアップロード済みの
    # メディアが孤児として残る）。
    def reserve_slot(slots)
      reserved = false
      slots.update do |remaining|
        reserved = remaining.positive?
        reserved ? remaining - 1 : remaining
      end
      return reserved
    end

    # ⚠ **失敗したら枠を返す。**返さないと、取得に失敗しただけで後続の添付が
    # 枠切れで落ちる（従来は枠を先に取らないので起きなかった退行）。
    def upload_attachment(payload, uri, slots)
      payload[attachment_field].push(upload(uri))
      result.push(source_url: uri.to_s)
    rescue
      slots.increment
      raise
    end
  end
end
