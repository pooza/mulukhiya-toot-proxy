module Mulukhiya
  class SlackAlertHandler < Handler
    def handle_alert(error, params = {})
      SlackService.broadcast(error)
      return error
    end

    def disable?
      return false unless config['/alert/slack/hooks'].present? rescue false
      return super
    end
  end
end
