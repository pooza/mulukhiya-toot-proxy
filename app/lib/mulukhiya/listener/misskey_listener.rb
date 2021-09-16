module Mulukhiya
  class MisskeyListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)['body']
      method_name = create_method_name(payload['type'])
      logger.info(class: self.class.to_s, method: method_name)
      send(method_name.to_sym, payload)
    rescue NoMethodError
      logger.error(class: self.class.to_s, method: method_name, message: 'method undefined')
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
    end

    def handle_mention(payload)
      Event.new(:mention, {sns: sns}).dispatch(payload)
    end

    def handle_followed(payload)
      Event.new(:follow, {sns: sns}).dispatch(payload)
    end

    def self.sender(payload)
      return Environment.account_class.get(id: payload.dig('body', 'user', 'id'))
    rescue => e
      logger.error(error: e)
    end

    def self.start
      EM.run do
        listener = MisskeyListener.new

        listener.client.on :close do |e|
          raise Ginseng::GatewayError, e.message
        end

        listener.client.on :error do |e|
          raise Ginseng::GatewayError, e.message
        end

        listener.client.on :message do |message|
          listener.receive(message)
        end
      end
    rescue => e
      @client = nil
      logger.error(error: e)
      sleep(config['/websocket/retry/seconds'])
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
