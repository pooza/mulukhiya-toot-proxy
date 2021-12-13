module Mulukhiya
  class LineAlertHandler < AlertHandler
    def disable?
      return true unless LineService.config?
      return super
    end

    def alert(params = {})
      LineService.new.say(error.to_h)
    end

    def id
      return config['/handler/line_alert/to'] rescue nil
    end

    def token
      return config['/handler/line_alert/token'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/handler/line_alert/token']
    end
  end
end
