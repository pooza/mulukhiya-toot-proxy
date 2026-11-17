module Mulukhiya
  # 利用者の設定で止められるのは `toggleable?` なハンドラだけ (#4196)。
  #
  # ⚠ 以前は `toggleable` を見ておらず、`/config/update` からなら `invalid_command` なども
  # 利用者が止められた。既に止めている設定も、ここで無視されることを確かめる。
  # ⚠ 実在のハンドラは多くが `disable?` を上書きしているので、`Handler#disable?` だけを持つ
  # 試験用のハンドラで確かめる。`Handler.new` は DB を触るので `allocate` で組む。
  class HandlerToggleableGateTest < TestCase
    class ToggleableProbeHandler < Handler
      def self.handler_config(*keys)
        return {toggleable: true}[keys.first]
      end
    end

    class FixedProbeHandler < Handler
      def self.handler_config(*keys)
        return {toggleable: false}[keys.first]
      end
    end

    FakeAccount = Struct.new(:disabled_names) do
      def disable?(handler)
        return disabled_names.member?(handler.underscore)
      end
    end

    FakeService = Struct.new(:account)

    GLOBAL_KEY = '/handler/fixed_probe/disable'.freeze

    def teardown
      config[GLOBAL_KEY] = false
    end

    def create_handler(handler_class, disabled_names)
      handler = handler_class.allocate
      handler.instance_variable_set(:@sns, FakeService.new(FakeAccount.new(disabled_names)))
      return handler
    end

    def test_toggleable_follows_user_config
      assert_predicate(create_handler(ToggleableProbeHandler, ['toggleable_probe']), :disable?)
      assert_false(create_handler(ToggleableProbeHandler, []).disable?)
    end

    # ⚠⚠ **これが本命。**以前は true になっていた。
    def test_non_toggleable_ignores_user_config
      assert_false(create_handler(FixedProbeHandler, ['fixed_probe']).disable?)
    end

    # サーバー全体の設定は、切り替えられないハンドラにも効く。
    def test_non_toggleable_follows_global_config
      config[GLOBAL_KEY] = true

      assert_predicate(create_handler(FixedProbeHandler, []), :disable?)
    end
  end
end
