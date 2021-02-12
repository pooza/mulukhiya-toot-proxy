module Mulukhiya
  class SlackAlertHandler < Handler
    def handle_alert(error, params = {})
      SlackService.broadcast(error.to_h)
      return error
    end

    def disable?
      return true unless config['/alert/slack/hooks'].present?
      return super
    rescue Ginseng::ConfigError
      return true
    end
  end
end
