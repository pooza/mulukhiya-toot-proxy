require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class Listener
    include Package
    include SNSMethods
    attr_reader :client, :uri, :sns

    def verify_peer?
      return config["/#{Environment.controller_name}/streaming/verify_peer"]
    end

    def keepalive
      return config['/websocket/keepalive']
    end

    private

    def initialize
      @sns = info_agent_service
      @uri = @sns.streaming_uri
      @client = Faye::WebSocket::Client.new(uri.to_s, [], {
        tls: {
          verify_peer: verify_peer?,
        },
        ping: keepalive,
      })
      account_class.administrators.each do |admin|
        info_agent_service.notify(admin, 'リスナーからストリーミングAPIへ接続しました。')
      end
    end

    def create_method_name(name)
      return "handle_#{name.gsub(/[^[:word:]]+/, '_')}".underscore
    end
  end
end
