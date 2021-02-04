module Mulukhiya
  class SlackAlertHandler < Handler
    def handle_alert(error, params = {})
      SlackService.broadcast(error)
      return error
    end
  end
end
