module Mulukhiya
  class MisskeyListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)

      logger.info(websocket: payload)
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
    end

    def self.start
      EM.run do
        listener = MisskeyListener.new

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
    rescue => e
      @client = nil
      logger.error(error: e)
      sleep(5)
      retry
    end

    private

    def initialize
      super
      client.send({type: 'connect', body: {channel: 'main', id: 'main'}}.to_json)
    end
  end
end
