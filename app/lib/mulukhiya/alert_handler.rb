module Mulukhiya
  class AlertHandler < Handler
    def handle_alert(error, params = {})
      error.package = Package.full_name
      alert(error)
      return error
    end

    def alert(error, params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
