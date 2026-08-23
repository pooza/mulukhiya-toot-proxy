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
    WORKERS = 16

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

    # ⚠⚠ **ここが Codex P2（#4650）。**候補を「配る」形だと、枠切れで skip した
    # 候補は二度と戻らない。先頭が枠を全部押さえてそのうち 1 本が失敗すると、
    # **空いた枠を拾う者がいない**まま有効な添付が黙って落ちる。
    def test_released_slot_is_reused_by_later_candidate
      handler = build_handler(fail: ['https://example.com/2.png'])
      payload = {'media' => Concurrent::Array.new}

      run_consume(handler, payload, slots: 4, candidates: 5)

      # 5 候補・枠 4・1 本失敗 → 有効な 4 枚が積まれる。
      assert_equal(4, payload['media'].count)
      assert_equal(1, handler.dropped.count)
    end

    # 上限は決して超えない（枠を返す形にしても）。
    def test_never_exceeds_capacity_with_failures
      handler = build_handler(fail: ['https://example.com/1.png'])
      payload = {'media' => Concurrent::Array.new}

      run_consume(handler, payload, slots: 2, candidates: 6)

      assert_equal(2, payload['media'].count)
    end

    # image_url を持たない添付は「落ちた」扱いにせず、枠も消費しない。
    def test_attachment_without_image_url_costs_nothing
      handler = build_handler
      payload = {'media' => Concurrent::Array.new}
      queue = Queue.new
      queue.push({'text' => '本文だけ'})
      2.times {|i| queue.push({'image_url' => "https://example.com/#{i}.png"})}

      drive(handler, queue, payload, 2)

      assert_equal(2, payload['media'].count)
      assert_equal(0, handler.dropped.count)
    end

    private

    # `consume` を実インスタンスで動かすためのダブル。
    # ⚠ `initialize` で `super` を呼ばない（Handler#initialize は DB を要求する）。
    class HandlerDouble < WebhookImageHandler
      attr_reader :dropped, :uploaded

      # ⚠ `super` を呼ばない。`Handler#initialize` は SNS / DB を要求するので、
      # ここで呼ぶとテストが環境依存になる。使うのは `consume` の周辺だけ。
      def initialize(fail: []) # rubocop:disable Lint/MissingSuper
        @fail = fail
        @dropped = Concurrent::Array.new
        @uploaded = Concurrent::Array.new
      end

      def attachment_field = 'media'

      def result = @uploaded

      # ⚠ **失敗する側も時間をかける。**上限超過は「受け取ってから」判るので、
      # 実際に失敗が判明するのはダウンロードのあと。即座に raise すると、
      # 枠が返るのが skip より早くなって**旧実装でも通ってしまう**。
      def upload(uri)
        sleep(UPLOAD_DELAY)
        raise Ginseng::GatewayError, 'Too large content' if @fail.include?(uri.to_s)
        return uri.to_s
      end

      def drop_attachment(_error, attachment)
        @dropped.push(attachment)
      end
    end

    def build_handler(fail: [])
      return HandlerDouble.new(fail:)
    end

    def run_consume(handler, payload, slots:, candidates:)
      queue = Queue.new
      candidates.times {|i| queue.push({'image_url' => "https://example.com/#{i}.png"})}
      drive(handler, queue, payload, slots)
    end

    # ⚠ **ワーカー数は枠より多くする。**本体は `Parallel.processor_count`
    # （実機で 16）なので、枠 4 に対して常にワーカーのほうが多い。同数だと
    # 「全ワーカーが枠を持っている間に skip が起きる」条件を作れない。
    def drive(handler, queue, payload, slots)
      atomic = Concurrent::AtomicFixnum.new(slots)
      run_concurrently(WORKERS) {handler.send(:consume, queue, payload, atomic)}
    end

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
