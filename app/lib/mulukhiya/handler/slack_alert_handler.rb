module Mulukhiya
  class SlackAlertHandler < AlertHandler
    def disable?
      return true unless SlackService.config?
      return super
    end

    def alert(params = {})
      SlackService.broadcast(error.to_h.merge(node: sns.node_name))
    end

    def uris(&block)
      return enum_for(__method__) unless block
      handler_config(:hooks).filter_map {|v| Ginseng::URI.parse(v)}.each(&block)
    rescue Ginseng::ConfigError
      return nil
    end
  end
end
