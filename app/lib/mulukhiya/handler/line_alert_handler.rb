module Mulukhiya
  class LineAlertHandler < AlertHandler
    def disable?
      return false unless LineService.config?
      return super
    end

    def alert(error, params = {})
      LineService.new.say(error.to_h)
    end
  end
end
