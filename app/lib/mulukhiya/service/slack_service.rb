module Mulukhiya
  class SlackService < Ginseng::Slack
    include Package

    def self.all(&)
      return enum_for(__method__) unless block
      uris.map {|v| SlackService.new(v)}.each(&)
    end

    def self.uris(&)
      return enum_for(__method__) unless block
      return nil unless handler = Handler.create('slack_alert')
      return handler.uris.each(&)
    end

    def self.config?
      return uris.present? rescue false
    end
  end
end
