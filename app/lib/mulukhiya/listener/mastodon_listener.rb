require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class MastodonListener
    include Package
    include SNSMethods
    attr_reader :client, :uri, :sns

    def close(event)
      @client = nil
      e = Ginseng::GatewayError.new('close')
      e.message = {reason: event.reason}
      logger.error(error: e)
    end

    def error(event)
      @client = nil
      e = Ginseng::GatewayError.new('close')
      e.message = {reason: event.reason}
      logger.error(error: e)
    end

    def receive(message)
      data = JSON.parse(message.data)
      payload = JSON.parse(data['payload'])
      if data['event'] == 'notification'
        send("handle_#{payload['type']}_notification".to_sym, payload)
      else
        send("handle_#{data['event']}".to_sym, payload)
      end
    rescue => e
      logger.error(error: e, payload: payload)
    end

    def handle_follow_notification(payload)
      Event.new(:follow, {reporter: @reporter, sns: @sns}).dispatch(payload)
    end

    def handle_update(payload); end

    def handle_delete(payload); end

    def self.start
      EM.run do
        listener = MastodonListener.new

        listener.client.on :close do |e|
          listener.close(e)
          raise 'closed'
        end

        listener.client.on :error do |e|
          listener.error(e)
          raise 'error'
        end

        listener.client.on :message do |message|
          listener.receive(message)
        end
      end
    rescue
      sleep(5)
      retry
    end

    private

    def initialize
      @sns = info_agent_service
      @uri = @sns.create_streaming_uri
      @reporter = Reporter.new
      @client = Faye::WebSocket::Client.new(uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
      })
    end
  end
end
