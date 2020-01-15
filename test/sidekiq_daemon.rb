module Mulukhiya
  class SudekiqDaemonTest < TestCase
    def setup
      @daemon = SidekiqDaemon.new
    end

    def test_cmd
      assert_kind_of(Array, @daemon.cmd)
    end

    def test_motd
      assert_kind_of(String, @daemon.motd)
    end
  end
end
