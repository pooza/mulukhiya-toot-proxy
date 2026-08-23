module Mulukhiya
  class WebhookImageHandler < Handler
    include LogScrubber

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
      run_workers(queue, payload, slots)
      drain(queue)
    end

    private

    # ⚠⚠ **`Parallel.each` をやめた代償を自分で払う。**あちらが面倒を見ていた
    # 2 つが、素の `Thread.new` では落ちる:
    #
    # 1. **HTTP 計装**（`HandlerProfile`）はスレッドローカルで、`ParallelProbe` が
    #    `Parallel` にしか prepend されていない。引き継がないと webhook 添付の
    #    ダウンロード + アップロードが丸ごと `http_count: 0` になる
    # 2. **ワーカーの後始末**。`Parallel.each(in_threads:)` は `ensure` で
    #    `threads.each(&:kill)` していた。無いと、join が例外で打ち切られたときに
    #    走り続けたスレッドが**応答を組み立てた後**に `push` して孤児メディアを作る
    def run_workers(queue, payload, slots)
      counter = Thread.current[HandlerProfile::HTTP_KEY]
      workers = [Parallel.processor_count, queue.size].min
      threads = Array.new(workers) do
        Thread.new do
          Thread.current[HandlerProfile::HTTP_KEY] = counter if counter
          consume(queue, payload, slots)
        end
      end
      threads.each(&:join)
    ensure
      threads&.each(&:kill)
    end

    # ⚠⚠ **枠を取ってから候補を取り出す。**逆順（取り出してから枠を取る）だと、
    # 候補を握ったまま枠が取れずに降りる窓ができ、その間に別のワーカーが失敗して
    # 枠を返し終了すると、**その候補は誰にも拾われず黙って消える**。
    # 枠を先に取れば、失敗したワーカーは**自分が返した枠を自分で取り直す**ので
    # 候補の受け渡し自体が無くなる。
    #
    # ⚠ 候補を「配る」形（`Parallel.each`）に戻さないこと。枠切れで skip した候補が
    # 二度と戻らず、空いた枠が使われないまま有効な添付が落ちる (#4633・Codex P2)。
    def consume(queue, payload, slots)
      loop do
        break unless reserve_slot(slots)
        unless attachment = pop_attachment(queue)
          slots.increment
          break
        end
        unless uri = parse_image_uri(attachment)
          slots.increment
          next
        end
        upload_attachment(payload, uri, slots, attachment)
      end
    end

    # ⚠ **枠切れで残った候補も「落ちた」として残す (#4633)。**従来は完全に無音で、
    # 6 枚送って 4 枚しか付かなくても送信側にも運用者にも何も出なかった。
    # 取得失敗と上限超過だけ記録して枠切れを黙らせるのは、この Issue の趣旨に反する。
    def drain(queue)
      while attachment = pop_attachment(queue)
        record_drop('SlotExhausted', 'max media attachments exceeded', attachment)
      end
    end

    def pop_attachment(queue)
      return queue.pop(true)
    rescue ThreadError
      return nil
    end

    # ⚠ **`image_url` を持たない添付は正常。**Slack legacy attachments は
    # 本文だけのものが普通にあるので、落ちた扱いにしない。
    def parse_image_uri(attachment)
      return Ginseng::URI.parse(attachment['image_url'])
    rescue => e
      drop_attachment(e, attachment)
      return nil
    end

    # ⚠⚠ **握り潰しても黙って消さない (#4633)。**「1 枚落ちても投稿は通す」設計
    # 自体は正しいが、上限超過 (`/media/download/max_bytes`) も取得失敗も
    # **200 と作成済み投稿 ID が返るだけ**で、送信側は成功と区別できなかった。
    def drop_attachment(error, attachment)
      record_drop(error.class.to_s, error.message, attachment)
    end

    # ⚠⚠ **添付を丸ごと出さない (#4630)。**Slack legacy attachments の
    # `title` / `text` / `pretext` / `footer` / `author_name` / `fields[].value` は
    # **すべて投稿本文になる**ので、素で渡すと同じリリースで塞いだ穴を開け直す。
    # ⚠ **gem 側の `mask_url` は当てにならない。**あれは URL のクエリパラメータの
    # 値しか伏せないので、`image_url` 全体も本文も素通しする。
    # ⚠ `errors` 側も同じものを通す。`Reporter` が `summary` 経由で `logger.info`
    # へ流すため、片方だけ伏せても意味がない。
    def record_drop(reason, message, attachment)
      scrubbed = scrub_log_params(attachment)
      logger.error(error: 'webhook attachment dropped', reason:, attachment: scrubbed)
      errors.push(class: reason, message:, attachment: scrubbed)
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
