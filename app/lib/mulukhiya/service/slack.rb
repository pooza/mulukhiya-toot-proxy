module Mulukhiya
  class Slack < Ginseng::Slack
    include Package

    def self.all
      return enum_for(__method__) unless block_given?
      config['/alert/slack/hooks'].each do |url|
        yield Slack.new(url)
      end
    end
  end
end
