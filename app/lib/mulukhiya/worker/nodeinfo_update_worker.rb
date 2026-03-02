module Mulukhiya
  class NodeinfoUpdateWorker < Worker
    sidekiq_options retry: false

    def perform(params = {})
      NodeInfo.instance.update
      log(cached: NodeInfo.instance.cached?)
    end
  end
end
