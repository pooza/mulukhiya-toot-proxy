module Mulukhiya
  class ProgramUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, lock: :until_executed, on_conflict: :log

    def perform
      return unless controller_class.livecure?
      Program.instance.update
    end
  end
end
