module Mulukhiya
  class SlackAlertHandler < Handler
    def handle_alert(error, params = {})
      Slack.broadcast(error)
      return error
    end
  end
end
