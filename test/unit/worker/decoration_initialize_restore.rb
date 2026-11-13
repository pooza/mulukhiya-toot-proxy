module Mulukhiya
  # 実況のデコを戻す処理が、2 回目の呼び出しで利用者のデコを消さないこと (#4912)。
  # SNS へは行かない（サービスとアカウントを差し替える）。
  class DecorationInitializeRestoreTest < TestCase
    APPLIED = 'applied_id'.freeze

    class FakeUserConfig
      attr_reader :values

      def initialize(values)
        @values = values
      end

      def [](key)
        return @values.dig(*key.delete_prefix('/').split('/'))
      end

      def token
        return 'token'
      end

      def update(values)
        values.deep_stringify_keys.each do |key, value|
          @values[key] = (@values[key] || {}).merge(value).compact
        end
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
      @worker.define_singleton_method(:info_agent_service) {nil}
    end

    def test_restore_twice_keeps_decorations
      saved = [{'id' => 'mine'}]
      service = stub_service([{'id' => 'mine'}, {'id' => APPLIED}])
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED, 'saved_state' => saved})
      account = FakeAccount.new(config)

      # 番組の途中に手で戻す（`/decoration/restore`）
      @worker.restore_decoration(account)

      assert_equal([saved], service.updates)
      assert_nil(config['/decoration/saved_state'])

      # 戻したあとに利用者がデコを付け直し、そのあと予約が動く
      service.decorations = [{'id' => 'mine'}, {'id' => 'added_later', 'offsetX' => -0.25}]
      @worker.restore_decoration(account)

      assert_equal([saved], service.updates)
      assert_equal([{'id' => 'mine'}, {'id' => 'added_later', 'offsetX' => -0.25}], service.decorations)
    end

    # 付ける前にデコが無かった人は saved_state が残らない（空の配列は deep_compact で消える）。
    # それでも、付けたデコは外れること。
    def test_restore_without_saved_state_removes_applied_only
      service = stub_service([{'id' => APPLIED, 'url' => 'https://example.com/a.webp'}])
      account = FakeAccount.new(FakeUserConfig.new('decoration' => {'id' => APPLIED}))
      @worker.restore_decoration(account)

      assert_equal([[]], service.updates)
    end

    def test_restored_decorations
      config = FakeUserConfig.new('decoration' => {'id' => APPLIED})
      account = FakeAccount.new(config)
      service = FakeService.new([
        {'id' => 'a', 'angle' => 0.25, 'url' => 'https://example.com/a.webp'},
        {'id' => APPLIED},
      ])

      assert_equal([{'id' => 'a', 'angle' => 0.25}], @worker.restored_decorations(service, account))

      service.decorations = [{'id' => 'a'}]

      assert_nil(@worker.restored_decorations(service, account))

      config.values['decoration'].delete('id')
      service.decorations = [{'id' => APPLIED}]

      assert_nil(@worker.restored_decorations(service, account))
    end

    private

    def stub_service(decorations)
      service = FakeService.new(decorations)
      service_class = Class.new
      service_class.define_singleton_method(:new) {service}
      @worker.define_singleton_method(:sns_class) {service_class}
      return service
    end
  end
end
