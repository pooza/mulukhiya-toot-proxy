require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class Listener
    include Package
    include SNSMethods
    attr_reader :client, :uri, :sns

    private

    def initialize
      @sns = info_agent_service
      @uri = @sns.streaming_uri
      @client = Faye::WebSocket::Client.new(uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
      })
    end
  end
end
