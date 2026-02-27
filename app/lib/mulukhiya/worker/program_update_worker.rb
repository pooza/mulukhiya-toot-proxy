module Mulukhiya
  class ProgramUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def perform(params = {})
      Program.instance.update
      log(programs: Program.instance.count)
    end
  end
end
