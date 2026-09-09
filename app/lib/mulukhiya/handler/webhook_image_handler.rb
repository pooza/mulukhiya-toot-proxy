module Mulukhiya
  class WebhookImageHandler < Handler
    include LogScrubber

    # 内部例外を丸めて返すときの文言 (#4694)。⚠ **原文は syslog に残す**ので、
    # 運用側の切り分けは失われない。
    GENERIC_DROP_MESSAGE = 'attachment could not be processed'.freeze

    # 殺したワーカーが `ensure` を走り終えるのを待つ上限 (秒) (#4694)。
    # ⚠ 待たないと、**処理中だった添付を「落ちた」と報告した直後にワーカーが
    # 成功で消す**（あるいはその逆の）競合が残る。
    WORKER_KILL_WAIT = 1

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

    # ⚠⚠ **`drain` は `ensure` に置く (#4694)。**#4657 の `thread.kill` は
    # `run_workers` の `threads.each(&:join)` を途中で切るので、素直に後ろへ
    # 書くと**タイムアウト経路でだけ実行されない**。`drain` は「枠切れ・未処理で
    # 残った添付」を `record_drop` する**唯一の経路**なので、走らないと
    # 🔴 **キューに残った添付が syslog にも応答にも 1 行も残らない。**
    #
    # ⚠ 5.35.0 までは殺されなかったので、応答には間に合わないものの syslog には
    # 残っていた。**#4633 で塞いだ穴が、タイムアウト経路でだけ開き直していた。**
    #
    # ⚠ `Thread#kill` は殺されるスレッドの `ensure` を走らせる。この
    # `handle_pre_webhook` 自身が殺される側なので、ここに置けば必ず通る。
    def handle_pre_webhook(payload, params = {})
      payload.deep_stringify_keys!
      payload[attachment_field] = Concurrent::Array.new(payload[attachment_field] || [])
      queue = Queue.new
      (payload['attachments'] || []).each {|v| queue.push(v)}
      slots = create_slots(payload)
      # ⚠⚠ **取り出し済みで処理中の添付も控える（PR #4713 の Codex P1）。**
      # `pop_attachment` はキューから**取り除いてから**アップロードに入るので、
      # その最中に殺されると 🔴 **キューにも残らず `rescue` も通らない**
      # （`Thread#kill` は `rescue => e` を通さない）。**添付 1 枚 = ワーカー 1 本**
      # という最も普通の形でキューが空になり、`drain` だけでは何も残らなかった。
      # ⚠⚠ **`Concurrent::Array` ではなく Hash（PR #4713 の Codex P1）。**
      # `Array#delete` は**値の等価**で消すので、**同じ内容の添付が 2 枚あると、
      # 先に終わったワーカーがまだ走っている別ワーカーの分まで消す**。
      # そのワーカーが締切で殺されると、キューにも `inflight` にも残らず
      # **また無音で落ちる**。**同一性**で 1 件ずつ独立に扱う。
      inflight = Concurrent::Hash.new.tap(&:compare_by_identity)
      run_workers(queue, payload, slots, inflight)
    ensure
      drain(queue, inflight) if queue
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
    def run_workers(queue, payload, slots, inflight)
      counter = Thread.current[HandlerProfile::HTTP_KEY]
      workers = [Parallel.processor_count, queue.size].min
      threads = Array.new(workers) do
        Thread.new do
          Thread.current[HandlerProfile::HTTP_KEY] = counter if counter
          consume(queue, payload, slots, inflight)
        end
      end
      threads.each(&:join)
    ensure
      threads&.each(&:kill)
      # ⚠ **殺した後に待つ (#4694)。**待たないと、外側の `drain` が読む `inflight` が
      # ワーカーの `ensure` と競合する。⚠ 待ちきれなくても先へ進む（ここは既に
      # 劣化した経路なので、投稿経路ごと止めない）。
      threads&.each {|thread| thread.join(WORKER_KILL_WAIT)}
    end

    # ⚠⚠ **枠を取ってから候補を取り出す。**逆順（取り出してから枠を取る）だと、
    # 候補を握ったまま枠が取れずに降りる窓ができ、その間に別のワーカーが失敗して
    # 枠を返し終了すると、**その候補は誰にも拾われず黙って消える**。
    # 枠を先に取れば、失敗したワーカーは**自分が返した枠を自分で取り直す**ので
    # 候補の受け渡し自体が無くなる。
    #
    # ⚠ 候補を「配る」形（`Parallel.each`）に戻さないこと。枠切れで skip した候補が
    # 二度と戻らず、空いた枠が使われないまま有効な添付が落ちる (#4633・Codex P2)。
    def consume(queue, payload, slots, inflight)
      loop do
        break unless reserve_slot(slots)
        unless attachment = pop_attachment(queue)
          slots.increment
          break
        end
        # ⚠ **取り出したら控える。**外した瞬間から `ensure` で外すまでの間に
        # 殺されると、この添付はどこからも辿れなくなる（PR #4713 の Codex P1）。
        inflight[attachment] = attachment
        unless uri = parse_image_uri(attachment)
          slots.increment
          inflight.delete(attachment)
          next
        end
        upload_attachment(payload, uri, slots, attachment)
        # ⚠⚠ **`ensure` で外さない。**`Thread#kill` でも `ensure` は走るので、
        # **殺された添付まで「片付いた」ことにしてしまう**（それでは元の穴のまま）。
        # ⚠ `upload_attachment` は自前の `rescue` で失敗を記録して**正常に返る**ので、
        # ここへ来たら成否によらず「処理は終わった」と言える。
        inflight.delete(attachment)
      end
    end

    # ⚠ **枠切れで残った候補も「落ちた」として残す (#4633)。**従来は完全に無音で、
    # 6 枚送って 4 枚しか付かなくても送信側にも運用者にも何も出なかった。
    # 取得失敗と上限超過だけ記録して枠切れを黙らせるのは、この Issue の趣旨に反する。
    # ⚠ `inflight` は**取り出し済みで処理中だった**もの（PR #4713 の Codex P1）。
    # 枠切れ（キューに残った）とは理由が違うので、別の `class` で残す。
    def drain(queue, inflight = nil)
      while attachment = pop_attachment(queue)
        record_drop('SlotExhausted', 'max media attachments exceeded', attachment)
      end
      inflight&.each_value do |attachment|
        record_drop('Timeout', 'handler timed out while uploading', attachment)
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
      record_drop(error.class.to_s, client_message(error), attachment, detail: error.message)
    end

    # 送信側へ返してよいメッセージ (#4694)。
    #
    # ⚠⚠ **`upload_attachment` の rescue は全例外を拾う。**素通しすると
    # `Errno::EACCES - /home/mulukhiya/.../tmp/media/xxxx.jpg`（**サーバー内の
    # 絶対パス**）や `PG::ConnectionBad: connection to server at "127.0.0.1",
    # port 6432 failed`（**内部ホスト・ポート**）がそのまま第三者へ返る。
    # ⚠ webhook は第三者システムへ配るものなので、digest を持つ相手に限られる
    # ことは緩和材料にならない。
    #
    # ⚠ **`InternalGatewayError#client_message` と同じ方針**（内部メソッド名と
    # 上流ステータスを外へ出さない）。あちらと非対称なままにしない。
    # ⚠ **原文は syslog には残す。**外に出さないことと、こちらが見られなくなる
    # ことは別（`record_drop` の `detail:`）。
    def client_message(error)
      return error.message if error.is_a?(Ginseng::Error)
      return GENERIC_DROP_MESSAGE
    end

    # ⚠⚠ **添付を丸ごと出さない (#4630)。**Slack legacy attachments の
    # `title` / `text` / `pretext` / `footer` / `author_name` / `fields[].value` は
    # **すべて投稿本文になる**ので、素で渡すと同じリリースで塞いだ穴を開け直す。
    # ⚠ **gem 側の `mask_url` は当てにならない。**あれは URL のクエリパラメータの
    # 値しか伏せないので、`image_url` 全体も本文も素通しする。
    # ⚠ `errors` 側も同じものを通す。`Reporter` が `summary` 経由で `logger.info`
    # へ流すため、片方だけ伏せても意味がない。
    # ⚠ `detail:` は **syslog にだけ**出す原文 (#4694)。送信側へ返すのは
    # `message`（丸めた側）。
    def record_drop(reason, message, attachment, detail: nil)
      scrubbed = scrub_log_params(attachment)
      logger.error(
        error: 'webhook attachment dropped',
        reason:,
        message: detail || message,
        attachment: scrubbed,
      )
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
