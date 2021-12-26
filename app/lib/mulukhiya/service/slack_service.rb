module Mulukhiya
  class SlackService < Ginseng::Slack
    include Package

    def self.all(&block)
      return enum_for(__method__) unless block
      uris.map {|v| SlackService.new(v)}.each(&block)
    end

    def self.uris(&block)
      return Handler.create('slack_alert')&.uris
    end

    def self.config?
      return uris.present? rescue false
    end
  end
end
