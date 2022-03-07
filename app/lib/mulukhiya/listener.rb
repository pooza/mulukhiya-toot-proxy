require 'faye/websocket'

module Mulukhiya
  class Listener
    include Package
    include SNSMethods
    attr_reader :client, :uri, :sns

    def verify_peer?
      return config["/#{Environment.controller_name}/streaming/verify_peer"]
    end

    def root_cert_file
      return config["/#{Environment.controller_name}/streaming/root_cert_file"]
    rescue
      return ENV['SSL_CERT_FILE']
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
          root_cert_file:,
          logger:,
        },
        ping: keepalive,
      })
      notify('リスナーからストリーミングAPIへ接続しました。', {administrators: true})
    end

    def create_method_name(name)
      return "handle_#{name.gsub(/[^[:word:]]+/, '_')}".underscore
    end
  end
end
