module MulukhiyaTootProxy
  class ThinDaemonTest < TestCase
    def setup
      @daemon = ThinDaemon.new
    end

    def test_cmd
      assert_kind_of(Array, @daemon.cmd)
    end

    def test_motd
      assert_kind_of(String, @daemon.motd)
    end

    def test_root_uri
      assert_kind_of(Ginseng::URI, @daemon.root_uri)
    end
  end
end
