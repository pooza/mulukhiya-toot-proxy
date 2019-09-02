module MulukhiyaTootProxy
  class SudekiqDaemonTest < Test::Unit::TestCase
    def setup
      @daemon = SidekiqDaemon.new
    end

    def test_cmd
      assert(@daemon.cmd.is_a?(Array))
    end

    def test_motd
      assert(@daemon.motd.is_a?(String))
    end
  end
end
