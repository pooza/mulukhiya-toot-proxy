require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class MastodonListener
    include Package
    include SNSMethods
    attr_reader :client, :uri

    def open
      logger.info(class: self.class.to_s, message: 'open', uri: @uri.to_s)
    end

    def close(event)
      @client = nil
      logger.error(class: self.class.to_s, message: 'close', reason: event.reason)
    end

    def error(event)
      @client = nil
      logger.error(class: self.class.to_s, message: 'error', reason: event.reason)
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

    def handle_mention_notification(payload)
      SlackService.broadcast(payload)
    end

    def handle_follow_notification(payload); end

    def handle_update(payload); end

    def handle_delete(payload); end

    def self.start
      EM.run do
        listener = MastodonListener.new

        listener.client.on :open do |e|
          listener.open
        end

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
      @mastodon = info_agent_service
      @uri = @mastodon.create_streaming_uri
      @client = Faye::WebSocket::Client.new(@uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
      })
    end
  end
end
