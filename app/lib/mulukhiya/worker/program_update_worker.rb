module Mulukhiya
  class ProgramUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, lock: :until_executed

    def perform
      Program.instance.update
    end
  end
end
