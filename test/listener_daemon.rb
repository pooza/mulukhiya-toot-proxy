module Mulukhiya
  class ListenerDaemonTest < TestCase
    def setup
      @daemon = ListenerDaemon.new
    end

    def test_command
      assert_kind_of(CommandLine, @daemon.command)
    end

    def test_motd
      assert_kind_of(String, @daemon.motd)
    end
  end
end
