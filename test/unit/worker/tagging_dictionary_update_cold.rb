module Mulukhiya
  # 投稿の経路からの更新の依頼（`'cold' => true`・#4628）。
  #
  # ⚠ Sidekiq が止まっている間に依頼が溜まる。復帰した瞬間にそれがまとめて上流を
  # 叩かないよう、**走る時点で本体キャッシュが埋まっていれば何もしない**。
  class TaggingDictionaryUpdateColdTest < TestCase
    def setup
      @calls = calls = []
      @refresh = TaggingDictionary.instance_method(:refresh)
      @cache = TaggingDictionary.instance_method(:cache)
      TaggingDictionary.define_method(:refresh) do |force: false|
        calls.push(force)
        self
      end
      @worker = TaggingDictionaryUpdateWorker.allocate
      @worker.define_singleton_method(:disable?) {false}
      @logged = logged = []
      @worker.define_singleton_method(:log) {|payload| logged.push(payload)}
    end

    def teardown
      TaggingDictionary.define_method(:refresh, @refresh)
      TaggingDictionary.define_method(:cache, @cache)
    end

    def test_cold_request_is_skipped_when_cache_is_filled
      TaggingDictionary.define_method(:cache) {{}}
      @worker.perform('cold' => true)
      @worker.perform(cold: true)

      assert_empty(@calls)
      # ⚠ 何もしなかった回も 1 行残す（溜まった依頼が空振りに見えないように）。
      assert_equal([true, true], @logged.map {|v| v[:skipped]})
    end

    def test_cold_request_refreshes_when_cache_is_missing
      TaggingDictionary.define_method(:cache) {nil}
      @worker.perform('cold' => true)

      assert_equal([false], @calls)
    end

    # ⚠ 定時の更新は、埋まっていても必ず取りにいく。
    def test_scheduled_run_refreshes_even_when_filled
      TaggingDictionary.define_method(:cache) {{}}
      @worker.perform

      assert_equal([false], @calls)
    end

    # ⚠ 更新ワーカーは `lazy: true` で作る＝自分で依頼を出さない・二重に取りにいかない。
    def test_worker_does_not_refresh_twice
      TaggingDictionary.define_method(:cache) {nil}
      @worker.perform

      assert_equal([false], @calls)
    end
  end
end
