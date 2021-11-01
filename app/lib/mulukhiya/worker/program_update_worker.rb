module Mulukhiya
  class ProgramUpdateWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      return unless controller_class.livecure?
      Program.instance.update
    end
  end
end
