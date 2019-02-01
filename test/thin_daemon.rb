module MulukhiyaTootProxy
  class ThinDaemonTest < Test::Unit::TestCase
    def setup
      @daemon = ThinDaemon.new
    end

    def test_cmd
      assert_true(@daemon.cmd.is_a?(Array))
    end

    def test_child_pid
      assert_true(@daemon.child_pid.is_a?(Integer))
    end
  end
end
