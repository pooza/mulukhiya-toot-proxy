module Mulukhiya
  class ProgramUpdateWorker
    include Sidekiq::Worker
    include Package
    sidekiq_options retry: false, lock: :until_executed

    def perform
      return unless controller_class.livecure?
      Program.instance.update
    end
  end
end
