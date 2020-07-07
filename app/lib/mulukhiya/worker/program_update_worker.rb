module Mulukhiya
  class ProgramUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform
      Program.instance.update
    end
  end
end
