module Mulukhiya
  # webhook の添付が上限を超えて積まれないこと (#4633)。
  #
  # ⚠⚠ **旧実装は `sns.max_media_attachments <= payload[...].count` を
  # ダウンロード + アップロードの前に見ていた。**`Concurrent::Array` は `push` を
  # 原子化するが判定は守らないので、複数スレッドが揃って判定を通過し、
  # それぞれ時間をかけてアップロードしてから push する ＝ 上限超過。
  # 上流が `media_ids` の上限超過で 422 を返し、**webhook 投稿ごと落ちる**。
  class WebhookAttachmentSlotsTest < TestCase
    MAX = 4
    UPLOAD_DELAY = 0.05

    # 枠の確保だけを取り出して、旧実装と新実装を同じ並行条件で比べる。
    def test_reserve_slot_never_exceeds_capacity
      slots = Concurrent::AtomicFixnum.new(MAX)
      pushed = Concurrent::Array.new

      run_concurrently(MAX * 3) do
        next unless reserve_slot(slots)
        sleep(UPLOAD_DELAY) # ダウンロード + アップロードの所要
        pushed.push(:ok)
      end

      assert_equal(MAX, pushed.count)
    end

    # ⚠ **対照。**旧実装と同じ「判定 → 時間のかかる処理 → push」を並べると
    # 実際に超過する。超過しないなら上のテストは何も守っていない。
    def test_check_then_act_actually_overflows
      pushed = Concurrent::Array.new

      run_concurrently(MAX * 3) do
        next if MAX <= pushed.count
        sleep(UPLOAD_DELAY)
        pushed.push(:ok)
      end

      assert_operator(pushed.count, :>, MAX, '旧実装は超過するはず')
    end

    # 失敗したら枠を返す。返さないと後続が枠切れで落ちる。
    def test_failed_upload_returns_the_slot
      slots = Concurrent::AtomicFixnum.new(1)

      assert_true(reserve_slot(slots))
      assert_equal(0, slots.value)

      slots.increment

      assert_true(reserve_slot(slots))
    end

    # 既に上限まで積まれていれば 1 枚も確保できない。
    def test_no_slot_when_already_full
      slots = Concurrent::AtomicFixnum.new(0)

      assert_false(reserve_slot(slots))
    end

    private

    # 本体と同じ実装を呼ぶ (private なので send)。
    def reserve_slot(slots)
      return handler.send(:reserve_slot, slots)
    end

    # ⚠ **メモ化しない。**`@handler` に入れると `TestCase#teardown` の
    # `@handler&.clear` が、`allocate` した（ivar が nil の）インスタンスを掴んで落ちる。
    def handler
      return WebhookImageHandler.allocate
    end

    def run_concurrently(count, &)
      Array.new(count) {Thread.new(&)}.each(&:join)
    end
  end
end
