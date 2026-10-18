module Mulukhiya
  # ストリーミングを切った系統では listener を起動対象に入れない（PR #4844 の Codex P1）。
  # ⚠ 入れると `nil.start` で落ち、`/health` も 503 になる（Pleroma 系は listener を持たない）。
  class ListenerDaemonStreamingTest < TestCase
    def setup
      Environment.singleton_class.alias_method(:__orig_controller_class, :controller_class)
    end

    def teardown
      super
      Environment.singleton_class.alias_method(:controller_class, :__orig_controller_class)
      Environment.singleton_class.remove_method(:__orig_controller_class)
    end

    def test_disabled_without_streaming
      no_streaming = Class.new {def self.streaming? = false}
      Environment.define_singleton_method(:controller_class) {no_streaming}

      assert_predicate(ListenerDaemon, :disable?)
      assert_false(Environment.daemon_classes.member?(ListenerDaemon))
    end
  end
end
