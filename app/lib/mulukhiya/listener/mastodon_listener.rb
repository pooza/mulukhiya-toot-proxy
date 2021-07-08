module Mulukhiya
  class MastodonListener < Listener
    def receive(message)
      data = JSON.parse(message.data)
      payload = JSON.parse(data['payload'])
      if data['event'] == 'notification'
        send("handle_#{payload['type']}_notification".to_sym, payload)
      else
        send("handle_#{data['event']}".to_sym, payload)
      end
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
    end

    def handle_follow_notification(payload)
      Event.new(:follow, {sns: sns}).dispatch(payload)
    end

    def handle_update(payload)
    end

    def handle_delete(payload)
    end

    def self.start
      EM.run do
        listener = MastodonListener.new

        listener.client.on :close do |e|
          raise Ginseng::GatewayError, event.reason
        end

        listener.client.on :error do |e|
          raise Ginseng::GatewayError, event.reason
        end

        listener.client.on :message do |message|
          listener.receive(message)
        end
      end
    rescue
      @client = nil
      logger.error(error: e)
      sleep(5)
      retry
    end
  end
end
