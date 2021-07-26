module Mulukhiya
  class MisskeyListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)['body']
      send("handle_#{payload['type'].underscore}".to_sym, payload)
    rescue NoMethodError
      logger.error(class: self.class.to_s, message: 'method undefined', method: method_name)
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
    end

    def handle_followed(payload)
      Event.new(:follow, {sns: sns}).dispatch(payload)
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
      client.send({type: 'connect', body: {channel: 'homeTimeline', id: 'home'}}.to_json)
      client.send({type: 'connect', body: {channel: 'localTimeline', id: 'local'}}.to_json)
    end
  end
end
