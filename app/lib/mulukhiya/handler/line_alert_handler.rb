module Mulukhiya
  class LineAlertHandler < AlertHandler
    def disable?
      return true unless LineService.config?
      return super
    end

    def alert(params = {})
      LineService.new.say(error.to_h)
    end
  end
end
