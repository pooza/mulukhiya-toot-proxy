module Mulukhiya
  class ValidateError < Ginseng::ValidateError
    attr_reader :raw_message

    def initialize(message)
      Slack.broadcast(message)
      @raw_message = message
      super
    end
  end
end
