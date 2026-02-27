module Mulukhiya
  class PumaDaemonRestartWorkerTest < TestCase
    def disable?
      return true if Environment.test?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:puma_daemon_restart)
    end

    def test_perform
      @worker.perform
    end
  end
end
