module Mulukhiya
  class SlackService < Ginseng::Slack
    include Package

    def self.all(&block)
      return enum_for(__method__) unless block
      uris.map {|v| SlackService.new(v)}.each(&block)
    end

    def self.uris(&block)
      return enum_for(__method__) unless block
      config['/alert/hooks'].map {|v| Ginseng::URI.parse(v)}.each(&block)
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return uris.present? rescue false
    end
  end
end
