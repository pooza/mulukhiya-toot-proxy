module Mulukhiya
  class PumaDaemonRestartWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      log(message: 'restarting')
      PumaDaemon.restart
      log(message: 'restarted')
    rescue => e
      e.log
      raise
    end
  end
end
