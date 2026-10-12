module Mulukhiya
  # 手動の更新は、ソースごとの取得間隔を無視して取りにいく (#4690・PR #4828 の Codex P2)。
  #
  # ⚠ TaggingDictionaryUpdateWorderTest と分けてあるのは、あちらが実物の辞書を引くから。
  # ここで見るのは「`force` が `refresh` まで届くか」だけで、環境に依らない。
  # ⚠ 更新ワーカーは `TaggingDictionary.new(lazy: true)` で作るので、`new` の中では `refresh` は
  # 走らない（#4628）。判定は「最後の呼び出し」と「true が混ざっていないか」で見る。
  class TaggingDictionaryUpdateForceTest < TestCase
    def setup
      @calls = calls = []
      @original = TaggingDictionary.instance_method(:refresh)
      TaggingDictionary.define_method(:refresh) do |force: false|
        calls.push(force)
        self
      end
      @worker = TaggingDictionaryUpdateWorker.allocate
      @worker.define_singleton_method(:disable?) {false}
      @worker.define_singleton_method(:log) {|*| nil}
    end

    def teardown
      TaggingDictionary.define_method(:refresh, @original)
    end

    # 定時（sidekiq-scheduler）は引数なし＝間隔に従う。
    def test_scheduled_run_does_not_force
      @worker.perform

      assert_not_empty(@calls)
      assert_not_include(@calls, true)
    end

    # ⚠ Sidekiq の引数は JSON を往復するので、キーは文字列で来る。
    def test_manual_run_forces
      @worker.perform('force' => true)

      assert_true(@calls.last)
    end

    # 🔴 development / test では `Worker.perform_async` がキーをシンボルにして同期で呼ぶ
    # （PR #4828 の Codex P2）。入口から通して、`force` が届くこと。
    def test_manual_run_forces_through_synchronous_dispatch
      worker = @worker
      original = TaggingDictionaryUpdateWorker.method(:new)
      TaggingDictionaryUpdateWorker.define_singleton_method(:new) {|*| worker}
      TaggingDictionaryUpdateWorker.perform_async('force' => true)

      assert_true(@calls.last)
    ensure
      TaggingDictionaryUpdateWorker.define_singleton_method(:new, original)
    end

    # ⚠ 真偽値の `true` だけを通す（文字列やシンボルのキーで、黙って全取得に倒さない）。
    def test_other_params_do_not_force
      [{'force' => 'true'}, {force: 'true'}, {'force' => 1}, {}, nil, 'force'].each do |params|
        @worker.perform(params)
      end

      assert_not_empty(@calls)
      assert_not_include(@calls, true)
    end

    # 管理画面と rake の入口が `force` を渡していること。
    def test_manual_entry_points_pass_force
      [
        'app/lib/mulukhiya/controller/api_controller.rb',
        'app/task/mulukhiya/tagging.rb',
      ].each do |path|
        source = File.read(File.join(Mulukhiya.dir, path))

        assert_include(source, "TaggingDictionaryUpdateWorker.perform_async('force' => true)", path)
      end
    end
  end
end
