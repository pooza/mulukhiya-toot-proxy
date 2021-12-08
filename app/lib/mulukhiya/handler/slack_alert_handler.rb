module Mulukhiya
  class SlackAlertHandler < AlertHandler
    def disable?
      return true unless SlackService.config?
      return super
    end

    def alert(params = {})
      SlackService.broadcast(error.to_h.merge(node: sns.node_name))
    end
  end
end
