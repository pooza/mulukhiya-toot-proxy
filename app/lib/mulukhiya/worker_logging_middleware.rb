module Mulukhiya
  class WorkerLoggingMiddleware
    include Package

    def call(worker, job, queue)
      worker_name = worker.respond_to?(:underscore) ? worker.underscore : worker.class.to_s
      jid = job['jid']
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      logger.info(worker: worker_name, jid:, queue:, status: 'start')
      yield
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
      logger.info(worker: worker_name, jid:, queue:, status: 'done', elapsed:)
    rescue => e
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
      logger.error(
        worker: worker_name, jid:, queue:,
        status: 'fail', elapsed:,
        error: e.class.to_s, message: e.message
      )
      raise
    end
  end
end
