module Mulukhiya
  class LineAlertHandler < Handler
    def handle_alert(error, params = {})
      error.package = Package.full_name
      LineService.new.say(config['/alert/line/to'], error.to_h)
      return error
    end

    def disable?
      return !LineService.config?
    end
  end
end
