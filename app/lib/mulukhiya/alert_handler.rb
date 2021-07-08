module Mulukhiya
  class AlertHandler < Handler
    attr_reader :error

    def handle_alert(error, params = {})
      error.package = Package.full_name
      @error = error
      alert
    end

    def alert(params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
