module Mulukhiya
  class SlackAlertHandler < AlertHandler
    def disable?
      return true unless config['/alert/slack/hooks'].present? rescue true
      return super
    end

    def alert(error, params = {})
      SlackService.broadcast(error.to_h)
    end
  end
end
