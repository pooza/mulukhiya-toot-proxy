module MulukhiyaTootProxy
  class ThinDaemonTest < Test::Unit::TestCase
    def setup
      @daemon = ThinDaemon.new
    end

    def test_cmd
      assert(@daemon.cmd.is_a?(Array))
    end

    def test_child_pid
      return if Environment.ci?
      assert(@daemon.child_pid.positive?)
    end

    def test_motd
      assert(@daemon.motd.is_a?(String))
    end

    def test_root_uri
      assert(@daemon.root_uri.is_a?(Ginseng::URI))
    end
  end
end
