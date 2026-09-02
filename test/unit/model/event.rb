module Mulukhiya
  class EventTest < TestCase
    def setup
      @event = Event.new(:pre_toot)
    end

    def test_all
      Event.all do |event|
        assert_kind_of(Event, event)
      end
    end

    def test_handlers
      @event.handlers do |handler|
        assert_kind_of(Handler, handler)
      end
    end

    def all_handlers
      @event.handlers do |handler|
        assert_kind_of(Handler, handler)
        assert_boolean(handler.disable?)
        assert_boolean(handler.verbose?)
      end
    end

    def test_syms
      assert_kind_of(Set, Event.syms)
      Event.syms.each do |sym|
        assert_kind_of(Symbol, sym)
      end
    end

    def test_resolve_pipeline
      names = @event.all_handler_names.to_a

      assert_predicate(names, :present?, 'Pipeline should resolve handlers')
    end

    def test_syms_coverage
      syms = Event.syms

      assert_includes(syms, :pre_toot)
      assert_includes(syms, :post_toot)
      assert_includes(syms, :alert)
    end

    # ⚠⚠ **`Thread#kill` は終了を「要求」するだけ (#4657 の Codex P2)。**
    # 待たずに返すと、ハンドラの `ensure` が走っている最中に呼び出し側が
    # dispatch / post へ進み、**投稿の後から添付が push される窓**が残る。
    # ＝ `thread.kill` を足した目的そのものが果たされない。
    #
    # ⚠ `thread.join` を外すと「後始末はまだ終わっていない」で落ちること、
    # `thread.kill` ごと外すと `errors` が積まれる前に本体が走り続けることを
    # どちらも実測で確認している。
    def test_timeout_waits_for_the_killed_handler_to_finish
      handler = TimeoutHandlerDouble.new

      @event.send(:run_handler, handler, {}, nil)

      assert_predicate(handler.cleaned_up, :present?, '後始末を待たずに戻っている')
      assert_equal([{message: 'timeout', timeout: '0.1s'}], handler.errors)
    end

    # 待つのは「終わるまで」であって固定の待機ではない。すぐ死ぬハンドラで
    # `HANDLER_KILL_WAIT` 秒ぶら下がらないこと（投稿経路の遅延になる）。
    def test_timeout_does_not_wait_the_whole_limit
      handler = TimeoutHandlerDouble.new(cleanup: 0)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @event.send(:run_handler, handler, {}, nil)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_operator(elapsed, :<, Event::HANDLER_KILL_WAIT)
    end

    # `handle_pre_toot` が返らないハンドラのダブル。`ensure` に後始末を置き、
    # 「殺されたあと、戻る前にそこまで終わっているか」を可視化する。
    class TimeoutHandlerDouble
      attr_reader :errors, :cleaned_up

      def initialize(cleanup: 0.3)
        @errors = []
        @cleaned_up = nil
        @cleanup = cleanup
      end

      def timeout = 0.1

      def handle_pre_toot(_payload, _params)
        sleep 10
      ensure
        sleep @cleanup
        @cleaned_up = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
