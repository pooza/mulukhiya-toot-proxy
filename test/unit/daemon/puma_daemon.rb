module Mulukhiya
  class PumaDaemonTest < TestCase
    def setup
      @daemon = PumaDaemon.new
    end

    def test_command
      assert_kind_of(CommandLine, @daemon.command)
    end

    def test_disable?
      assert_false(PumaDaemon.disable?)
    end
  end
end
