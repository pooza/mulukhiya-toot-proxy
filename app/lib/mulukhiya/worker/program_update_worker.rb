module Mulukhiya
  class ProgramUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def perform(params = {})
      Program.instance.update
    end
  end
end
