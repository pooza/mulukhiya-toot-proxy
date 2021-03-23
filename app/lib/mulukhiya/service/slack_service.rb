module Mulukhiya
  class SlackService < Ginseng::Slack
    include Package

    def self.all
      return enum_for(__method__) unless block_given?
      uris do |uri|
        yield SlackService.new(uri)
      end
    end

    def self.uris
      return enum_for(__method__) unless block_given?
      config['/alert/slack/hooks'].each do |href|
        yield Ginseng::URI.parse(href)
      end
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return uris.present? rescue false
    end
  end
end
