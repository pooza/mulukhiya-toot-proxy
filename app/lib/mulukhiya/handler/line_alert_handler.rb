module Mulukhiya
  class LineAlertHandler < AlertHandler
    def disable?
      return true unless LineService.config?
      return super
    end

    def alert(params = {})
      LineService.new.say(error.to_h.merge(node: sns.node_name))
    end

    def id
      return handler_config(:id)
    end

    def token
      return handler_config(:token).decrypt rescue handler_config(:token)
    end
  end
end
