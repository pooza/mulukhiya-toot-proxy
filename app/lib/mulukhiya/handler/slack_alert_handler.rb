module Mulukhiya
  class SlackAlertHandler < AlertHandler
    def alert(error, params = {})
      SlackService.broadcast(error.to_h)
    end

    def disable?
      return true unless config['/alert/slack/hooks'].present?
      return super
    rescue Ginseng::ConfigError
      return true
    end
  end
end
