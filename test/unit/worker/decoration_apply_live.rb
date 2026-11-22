module Mulukhiya
  # 実況のデコを付ける処理が、付けたデコを `/decoration/live` に残すこと (#4912)。
  # SNS へは行かない（サービスとアカウントを差し替える）。
  class DecorationApplyLiveTest < TestCase
    APPLIED = 'applied_id'.freeze
    STARTED = '2026-11-22T10:15:00+09:00'.freeze

    # ⚠ 引き方と書き方は本物（`UserConfig` / `UserConfigStorage#update`）に揃える。`[]` は末端のキーでしか
    # 引けない（`/decoration/live` は nil）。`dig` で引く作り物にしていたら、実機で live を読めていなかった。
    class FakeUserConfig
      attr_reader :values

      def initialize(values)
        @values = values
      end

      def [](key)
        return @values.key_flatten[key]
      end

      def token
        return 'token'
      end

      def update(values)
        @values = @values.deep_merge(values.deep_stringify_keys).deep_compact
      end
    end

    class FakeAccount
      attr_reader :user_config

      def initialize(user_config)
        @user_config = user_config
      end

      def acct
        return Acct.new('@decoration_apply_test@example.com')
      end
    end

    class FakeService
      attr_accessor :token, :decorations
      attr_reader :updates

      def initialize(decorations)
        @decorations = decorations
        @updates = []
      end

      def fetch_account_detail
        return {'avatarDecorations' => @decorations}
      end

      def fetch_avatar_decorations
        return [{'id' => APPLIED, 'name' => '実況中 ゴメちゃん'}, {'id' => 'other', 'name' => 'ほか'}]
      end

      def update_account(params)
        @updates.push(params[:avatarDecorations])
        @decorations = params[:avatarDecorations]
      end
    end

    def setup
      @worker = Worker.create(:decoration_apply)
    end

    def test_apply
      service = stub_service([{'id' => 'mine', 'angle' => 0.25, 'url' => 'https://example.com/m.webp'}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED})
      @worker.apply_decoration(FakeAccount.new(config), program: 'ダイの大冒険', restore_at: '2026-11-22T10:47:00+09:00')

      assert_equal([[{'id' => 'mine', 'angle' => 0.25}, {'id' => APPLIED}]], service.updates)
      assert_equal(
        {'id' => APPLIED, 'name' => '実況中 ゴメちゃん', 'program' => 'ダイの大冒険', 'restore_at' => '2026-11-22T10:47:00+09:00'},
        live(config),
      )
      assert_nil(config['/decoration/saved_state'], '丸ごとの保存はしない')
    end

    # 既に同じデコを付けていた人のデコは、利用者のもの。触らず、外す相手にもしない。
    def test_apply_owned
      service = stub_service([{'id' => APPLIED, 'offsetX' => 0.5}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED})
      @worker.apply_decoration(FakeAccount.new(config), program: 'ダイの大冒険')

      assert_empty(service.updates)
      assert_equal({'program' => 'ダイの大冒険'}, live(config))
    end

    # 同じ実況をもう一度始めても、付けたデコの位置は動かさない。
    def test_apply_again
      service = stub_service([{'id' => APPLIED, 'offsetX' => 0.5}, {'id' => 'mine'}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'live' => {'started_at' => STARTED, 'id' => APPLIED}})
      @worker.apply_decoration(FakeAccount.new(config), program: 'ダイの大冒険')

      assert_empty(service.updates)
      assert_equal(APPLIED, config['/decoration/live/id'])
    end

    # 前の実況のデコが残っていて、設定のデコが変わっていたら付け替える。
    def test_apply_replaces_previous
      service = stub_service([{'id' => 'mine'}, {'id' => 'other'}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'live' => {'started_at' => STARTED, 'id' => 'other', 'name' => 'ほか'}})
      @worker.apply_decoration(FakeAccount.new(config))

      assert_equal([[{'id' => 'mine'}, {'id' => APPLIED}]], service.updates)
      assert_equal({'id' => APPLIED, 'name' => '実況中 ゴメちゃん'}, live(config))
    end

    # 記録はデコを付ける前に書く。書き込みが落ちると、付いたデコが外れなくなる（5.48.0 のリリース前レビュー）。
    def test_live_is_saved_before_applying
      service = stub_service([])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED})
      seen = []
      service.define_singleton_method(:update_account) {|_params| seen.push(config['/decoration/live/id'])}
      @worker.apply_decoration(FakeAccount.new(config))

      assert_equal([APPLIED], seen)
    end

    def test_apply_without_decoration_id
      service = stub_service([])
      config = FakeUserConfig.new({})
      @worker.apply_decoration(FakeAccount.new(config))

      assert_empty(service.updates)
      assert_nil(live(config))
    end

    private

    def live(config)
      return DecorationInitializeWorker.live(config)&.except('started_at')
    end

    def stub_service(decorations)
      service = FakeService.new(decorations)
      service_class = Class.new
      service_class.define_singleton_method(:new) {service}
      @worker.define_singleton_method(:sns_class) {service_class}
      return service
    end
  end
end
