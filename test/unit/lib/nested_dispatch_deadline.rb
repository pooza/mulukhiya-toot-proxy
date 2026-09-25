module Mulukhiya
  # ネストした dispatch へ締切を引き継ぐこと (#4721)。
  #
  # ⚠⚠ **webhook_image → pre_upload の経路では、内側が自分の締切を配り直していた。**
  # `WebhookImageHandler` の添付ワーカー（素の `Thread.new`）へ締切を渡しておらず、
  # 内側の `Event#run_handler` も親の締切と比べなかったので、内側の変換は
  # **外側（webhook_image）の締切より後ろ**を締切だと思い込み、外側の kill が先に来る。
  # それでは #4696 で塞いだ「内側が先に切れる」が、ネストした経路でだけ開き直す。
  class NestedDispatchDeadlineTest < TestCase
    def setup
      @deadline = Thread.current[Event::HANDLER_DEADLINE_KEY]
      @event = Event.new(:pre_toot)
    end

    def teardown
      Thread.current[Event::HANDLER_DEADLINE_KEY] = @deadline
    end

    # 親の締切が無ければ（トップレベルの dispatch）自分の締切を使う。
    def test_own_deadline_without_parent
      assert_equal(100, @event.send(:nested_deadline, 100, nil))
    end

    # 🔴 **親のほうが近ければ親に従う。**内側が外側より後ろを締切にしてはいけない。
    def test_parent_deadline_wins_when_sooner
      assert_equal(50, @event.send(:nested_deadline, 100, 50))
    end

    # 自分のほうが近ければ自分に従う（親の締切で内側の上限を緩めない）。
    def test_own_deadline_wins_when_sooner
      assert_equal(50, @event.send(:nested_deadline, 50, 100))
    end

    # 🔴 `run_handler` が親の締切を実際に読むこと。⚠ 配線が外れても
    # 上の純粋なテストだけでは緑のままになる（#4583 と同型）。
    def test_run_handler_inherits_the_parent_deadline
      parent = monotonic + 3
      Thread.current[Event::HANDLER_DEADLINE_KEY] = parent

      assert_equal(parent, deadline_seen_by(handler_with_timeout(90)))
    end

    # 親より近い自分の締切は、そのまま効く。
    def test_run_handler_keeps_its_own_sooner_deadline
      Thread.current[Event::HANDLER_DEADLINE_KEY] = monotonic + 100_000
      seen = deadline_seen_by(handler_with_timeout(10))

      assert_operator(seen - monotonic, :<=, 10)
    end

    # 🔴 **添付ワーカーへ締切を渡すこと。**ワーカーは素の `Thread.new` なので、
    # 渡さないとワーカーの中の dispatch には親の締切が見えない。
    def test_webhook_workers_receive_the_deadline
      deadline = monotonic + 7
      Thread.current[Event::HANDLER_DEADLINE_KEY] = deadline
      seen = Concurrent::Array.new
      handler = WebhookImageHandler.allocate
      handler.define_singleton_method(:consume) do |*|
        seen.push(Thread.current[Event::HANDLER_DEADLINE_KEY])
      end
      queue = Queue.new
      queue.push({'image_url' => 'https://example.com/a.png'})

      handler.send(:run_workers, queue, {}, Concurrent::AtomicFixnum.new(1), {})

      assert_equal([deadline], seen.to_a)
    end

    private

    def monotonic
      return Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def handler_with_timeout(seconds)
      handler = Object.new
      handler.define_singleton_method(:timeout) {seconds}
      return handler
    end

    def deadline_seen_by(handler)
      seen = nil
      handler.define_singleton_method(:handle_pre_toot) do |_payload, _params|
        seen = Thread.current[Event::HANDLER_DEADLINE_KEY]
      end
      @event.send(:run_handler, handler, {}, nil)
      return seen
    end
  end
end
