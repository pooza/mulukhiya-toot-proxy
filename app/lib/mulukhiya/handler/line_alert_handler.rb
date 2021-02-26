module Mulukhiya
  class LineAlertHandler < AlertHandler
    def alert(error, params = {})
      LineService.new.say(config['/alert/line/to'], error.to_h)
    end

    def disable?
      return !LineService.config?
    end
  end
end
