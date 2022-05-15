module Mulukhiya
  class ListenerDaemonTest < TestCase
    def disable?
      return true unless controller_class.streaming?
      return true unless Environment.daemon_classes.member?(ListenerDaemon)
      return false
    end

    def setup
      @daemon = ListenerDaemon.new
    end

    def test_command
      assert_kind_of(CommandLine, @daemon.command)
    end

    def test_motd
      assert_kind_of(String, @daemon.motd)
    end

    def test_disable?
      assert_boolean(ListenerDaemon.disable?)
    end
  end
end
