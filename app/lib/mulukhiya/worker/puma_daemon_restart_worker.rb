module Mulukhiya
  class PumaDaemonRestartWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      PumaDaemon.restart
    end
  end
end
