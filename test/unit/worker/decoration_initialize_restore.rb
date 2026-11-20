module Mulukhiya
  # 実況のデコを戻す処理が、付けた 1 つだけを外し、利用者のデコを消さないこと (#4912)。
  # SNS へは行かない（サービスとアカウントを差し替える）。
  class DecorationInitializeRestoreTest < TestCase
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

      def username
        return 'decoration_restore_test'
      end

      def acct
        return Acct.new('@decoration_restore_test@example.com')
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

      def update_account(params)
        @updates.push(params[:avatarDecorations])
        @decorations = params[:avatarDecorations]
      end
    end

    def setup
      @worker = Worker.create(:decoration_initialize)
      @notices = notices = []
      notifier = Object.new
      notifier.define_singleton_method(:notify) {|_account, message| notices.push(message)}
      @worker.define_singleton_method(:info_agent_service) {notifier}
    end

    # 外すのは付けた 1 つだけ。番組の途中で動かしたデコ・足したデコは残る (#4912)。
    def test_restore_removes_applied_only
      service = stub_service([
        {'id' => 'mine', 'offsetX' => 0.5, 'url' => 'https://example.com/m.webp'},
        {'id' => APPLIED},
        {'id' => 'added_later'},
      ])
      config = FakeUserConfig.new('decoration' => {
        'id' => APPLIED,
        'live' => {'started_at' => STARTED, 'id' => APPLIED, 'name' => '実況中 ゴメちゃん', 'program' => 'ダイの大冒険'},
      })
      @worker.restore_decoration(FakeAccount.new(config))

      assert_equal([[{'id' => 'mine', 'offsetX' => 0.5}, {'id' => 'added_later'}]], service.updates)
      assert_nil(live(config))
      assert_equal(['ダイの大冒険の実況のために付けたデコ「実況中 ゴメちゃん」を、番組が終わったので外しました。'], @notices)
    end

    # 番組の途中で設定のデコを変えても、外すのは付けた方 (PR #4914 の Codex P2)。
    def test_restore_follows_live_id_not_config_id
      service = stub_service([{'id' => APPLIED}, {'id' => 'changed'}])
      config = FakeUserConfig.new('decoration' => {'id' => 'changed', 'live' => {'started_at' => STARTED, 'id' => APPLIED}})
      @worker.restore_decoration(FakeAccount.new(config))

      assert_equal([[{'id' => 'changed'}]], service.updates)
      assert_equal(['実況のために付けたデコを、番組が終わったので外しました。'], @notices)
    end

    def test_restore_twice_keeps_decorations
      service = stub_service([{'id' => 'mine'}, {'id' => APPLIED}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'live' => {'started_at' => STARTED, 'id' => APPLIED}})
      account = FakeAccount.new(config)

      # 番組の途中に手で戻す（`/decoration/restore`）。自分で戻したので通知しない
      @worker.restore_decoration(account, notify: false)

      assert_equal([[{'id' => 'mine'}]], service.updates)
      assert_empty(@notices)

      # 戻したあとに利用者が同じデコを付け直し、そのあと予約が動く
      service.decorations = [{'id' => 'mine'}, {'id' => APPLIED, 'offsetX' => -0.25}]
      @worker.restore_decoration(account)

      assert_equal(1, service.updates.count)
      assert_equal([{'id' => 'mine'}, {'id' => APPLIED, 'offsetX' => -0.25}], service.decorations)
    end

    # 実況を始めたとき既に同じデコを付けていた人は、`live` に `id` が無い＝外さない。
    def test_restore_keeps_owned_decoration
      service = stub_service([{'id' => APPLIED}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'live' => {'started_at' => STARTED, 'program' => 'ダイの大冒険'}})
      @worker.restore_decoration(FakeAccount.new(config))

      assert_empty(service.updates)
      assert_nil(live(config))
      assert_empty(@notices)
    end

    # 5.48.0 より前に付けた分（`saved_state` だけがある）は、設定のデコを外す。丸ごと上書きはしない。
    def test_restore_legacy_saved_state
      service = stub_service([{'id' => 'mine', 'angle' => 0.25}, {'id' => APPLIED}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'saved_state' => [{'id' => 'old'}]})
      @worker.restore_decoration(FakeAccount.new(config))

      assert_equal([[{'id' => 'mine', 'angle' => 0.25}]], service.updates)
      assert_nil(config['/decoration/saved_state'])
    end

    # 付けたことが分からないデコは外さない。
    def test_restore_without_marker_does_nothing
      service = stub_service([{'id' => APPLIED}])
      @worker.restore_decoration(FakeAccount.new(FakeUserConfig.new('decoration' => {'id' => APPLIED})))

      assert_empty(service.updates)
      assert_empty(@notices)
    end

    def test_restorable
      assert_true(DecorationInitializeWorker.restorable?(FakeUserConfig.new('decoration' => {'live' => {'started_at' => STARTED, 'id' => 'a'}})))
      assert_true(DecorationInitializeWorker.restorable?(FakeUserConfig.new('decoration' => {'saved_state' => [{'id' => 'a'}]})))
      assert_false(DecorationInitializeWorker.restorable?(FakeUserConfig.new('decoration' => {'id' => 'a'})))
      assert_false(DecorationInitializeWorker.restorable?(FakeUserConfig.new({})))
    end

    def test_live_status
      assert_equal({live: false}, DecorationInitializeWorker.live_status(FakeUserConfig.new({})))
      live = {'id' => APPLIED, 'name' => 'ゴメちゃん', 'program' => 'ダイの大冒険', 'restore_at' => '2026-11-22T10:47:00+09:00'}

      assert_equal(
        {live: true, id: APPLIED, name: 'ゴメちゃん', program: 'ダイの大冒険', restore_at: '2026-11-22T10:47:00+09:00'},
        DecorationInitializeWorker.live_status(FakeUserConfig.new('decoration' => {'live' => live.merge('started_at' => STARTED)})),
      )
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
