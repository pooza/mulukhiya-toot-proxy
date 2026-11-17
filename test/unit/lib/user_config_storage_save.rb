module Mulukhiya
  # 利用者の設定を書いたあとの保存（5.47.0 のリリース前レビュー）。
  # ⚠ Redis を使わずに確かめるため、`allocate` した上で `redis` を偽物に差し替える。
  class UserConfigStorageSaveTest < TestCase
    FakeClient = Struct.new(:calls, :error) do
      def call(*args)
        calls.push(args)
        raise error if error
        return 'Background saving scheduled'
      end
    end

    def setup
      @storage = UserConfigStorage.allocate
    end

    # 同期の `SAVE` ではなく、実行中なら後で取る `BGSAVE SCHEDULE` を撃つ。
    def test_schedules_background_save
      client = FakeClient.new([], nil)
      @storage.define_singleton_method(:redis) {client}
      @storage.save

      assert_equal([['BGSAVE', 'SCHEDULE']], client.calls)
    end

    # 保存に失敗しても例外を上げない（SET は済んでいるので、要求を失敗させない）。
    def test_save_failure_does_not_raise
      client = FakeClient.new([], RuntimeError.new('ERR Background save already in progress'))
      @storage.define_singleton_method(:redis) {client}

      assert_nothing_raised {@storage.save}
    end
  end
end
