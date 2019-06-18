module MulukhiyaTootProxy
  class ThinDaemonTest < Test::Unit::TestCase
    def setup
      @daemon = ThinDaemon.new
    end

    def test_cmd
      assert(@daemon.cmd.is_a?(Array))
    end

    def test_child_pid
      return if ENV['CI'].present?
      assert(@daemon.child_pid.is_a?(Integer))
    end

    def test_motd
      assert(@daemon.motd.is_a?(String))
    end

    def test_root_uri
      assert(@daemon.root_uri.is_a?(Addressable::URI))
    end
  end
end
