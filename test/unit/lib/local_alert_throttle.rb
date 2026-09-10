module Mulukhiya
  # Redis に印を書けないときの受け皿（5.37.0 リリース前レビューの赤）。
  #
  # ⚠⚠ **黙らず、連打もしない。**窓のあいだ 1 回だけ獲得でき、窓が明ければまた獲得できる。
  class LocalAlertThrottleTest < TestCase
    PREFIX = 'local_alert_throttle_test'.freeze

    def teardown
      LocalAlertThrottle.clear(PREFIX)
      super
    end

    # 🔴 **本体。**窓のあいだ 1 回だけ。
    def test_acquires_once_per_window
      assert(LocalAlertThrottle.acquire(key, 60), '1 回目が獲得できない（黙る）')
      refute(LocalAlertThrottle.acquire(key, 60), '2 回目も獲得できる（連打する）')
    end

    # 窓が明ければまた鳴る（永遠に黙らない）。
    def test_reacquires_after_the_window
      assert(LocalAlertThrottle.acquire(key, 0.05))
      sleep(0.1)

      assert(LocalAlertThrottle.acquire(key, 0.05), '窓が明けても獲得できない')
    end

    # ⚠ 鍵ごとに独立（別の型・別のルートを握り潰さない）。
    def test_keys_are_independent
      assert(LocalAlertThrottle.acquire(key('a'), 60))

      assert(LocalAlertThrottle.acquire(key('b'), 60), '別の鍵まで抑えている')
    end

    # ⚠⚠ **同じプロセスの複数スレッドが同時に来ても 1 本だけ。**
    # `Concurrent::Map#compute` は鍵ごとに原子的。
    def test_only_one_thread_acquires
      winners = Concurrent::Array.new
      Array.new(16) {Thread.new {winners.push(LocalAlertThrottle.acquire(key, 60))}}.each(&:join)

      assert_equal(1, winners.count(true), '同時に来た複数スレッドが獲得している')
    end

    private

    def key(suffix = 'x')
      return "#{PREFIX}/#{suffix}"
    end
  end
end
