module Mulukhiya
  # タイムアウトしたハンドラのスレッドを止める (#4657 の 6)。
  #
  # ⚠⚠ **従来は `errors` へ積むだけでワーカーは走り続けていた。**
  # `webhook_image` の timeout は 10 秒だが、超えたハンドラが `Webhook#post` の
  # `sns.post` より後に `push` すると、**上限は守れているのに投稿に載らない添付**が出る。
  class HandlerTimeoutTest < TestCase
    # `Event#run_handler` が触るのは `timeout` / `errors` / `send(method, ...)` だけ。
    class SlowHandler
      attr_reader :errors, :effects, :timeout

      # ⚠ **タイムアウト後に「書く」ハンドラ**を模す。放置すると `effects` に
      # 積まれてしまい、それが「投稿に載らない添付」の正体。
      def initialize(timeout:, work:)
        @timeout = timeout
        @work = work
        @errors = []
        @effects = []
        @started = Queue.new
      end

      def handle_pre_toot(_payload, _params)
        @started.push(true)
        sleep(@work)
        @effects << :late_write
      end

      def wait_until_started = @started.pop
    end

    def run_handler(handler)
      Event.new(:pre_toot).send(:run_handler, handler, {}, nil)
    end

    # 期待どおり終わるハンドラはそのまま通る。
    def test_fast_handler_completes
      handler = SlowHandler.new(timeout: 5, work: 0)
      run_handler(handler)

      assert_equal([], handler.errors)
      assert_equal([:late_write], handler.effects)
    end

    def test_timeout_is_recorded
      handler = SlowHandler.new(timeout: 0.05, work: 5)
      run_handler(handler)

      assert_equal(1, handler.errors.size)
      assert_equal('timeout', handler.errors.first[:message])
    end

    # ⚠⚠ **これが本命。**タイムアウト後にハンドラが書き足さないこと。
    # 従来はここが `[:late_write]` になっていた。
    def test_timed_out_handler_does_not_write_afterwards
      handler = SlowHandler.new(timeout: 0.05, work: 0.3)
      run_handler(handler)
      handler.wait_until_started
      # ワーカーが生きていれば、この待ちの間に late_write が積まれる。
      sleep(0.5)

      assert_equal([], handler.effects, 'タイムアウトしたスレッドが走り続けている')
    end
  end
end
