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
      queue = Queue.new
      (payload['attachments'] || []).each {|v| queue.push(v)}
      slots = create_slots(payload)
      workers = [Parallel.processor_count, queue.size].min
      Array.new(workers) {Thread.new {consume(queue, payload, slots)}}.each(&:join)
    end

    private

    # ⚠⚠ **候補を「配る」のではなく「取りに行く」形にする (#4633・Codex P2)。**
    # `Parallel.each` で候補を配ると、**枠切れで skip した候補は二度と戻らない**。
    # 先に枠を取る実装と組み合わせると、先頭の候補が枠を全部押さえ→そのうち 1 本が
    # 失敗して枠を返しても、**skip 済みの後続を拾う者がいない**＝空いた枠が
    # 使われないまま、有効な添付が黙って落ちる（候補 5・枠 4・先頭で 1 失敗なら 3 枚）。
    #
    # 取りに行く形なら、**失敗して枠を返したワーカーがそのまま次の候補に使う**。
    def consume(queue, payload, slots)
      loop do
        break unless attachment = pop_attachment(queue)
        next unless uri = parse_image_uri(attachment)
        unless reserve_slot(slots)
          # ⚠ **取り出したまま降りない。**別のワーカーが失敗して枠を返したときに
          # 拾える候補が消える。戻してから降りる。
          queue.push(attachment)
          break
        end
        upload_attachment(payload, uri, slots, attachment)
      end
    end

    def pop_attachment(queue)
      return queue.pop(true)
    rescue ThreadError
      return nil
    end

    # ⚠ **`image_url` を持たない添付は正常。**Slack legacy attachments は
    # 本文だけのものが普通にあるので、落ちた扱いにしない（枠も取らない）。
    def parse_image_uri(attachment)
      return Ginseng::URI.parse(attachment['image_url'])
    rescue => e
      drop_attachment(e, attachment)
      return nil
    end

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
    # 返した枠は `consume` のループが次の候補に使う。
    def upload_attachment(payload, uri, slots, attachment)
      payload[attachment_field].push(upload(uri))
      result.push(source_url: uri.to_s)
    rescue => e
      slots.increment
      drop_attachment(e, attachment)
    end
  end
end
