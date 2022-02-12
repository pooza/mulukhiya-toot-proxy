module Mulukhiya
  class MisskeyListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)['body']
      method_name = create_method_name(payload['type'])
      return send(method_name.to_sym, payload)
    rescue NoMethodError
      logger.info(class: self.class.to_s, method: method_name, message: 'method unimplemented')
    rescue => e
      e.log(payload: (payload rescue message.data))
    end

    def handle_mention(payload)
      Event.new(:mention, {sns:}).dispatch(payload)
    end

    def handle_followed(payload)
      Event.new(:follow, {sns:}).dispatch(payload)
    end

    def self.sender(payload)
      return Environment.account_class.get(id: payload.dig('body', 'user', 'id'))
    rescue => e
      e.log
    end

    def self.start
      EM.run do
        listener = MisskeyListener.new

        listener.client.on :close do
          Environment.account_class.administrators.each do |admin|
            info_agent_service.notify(admin, 'リスナーからストリーミングAPIへの接続が途絶えました。')
          end
        end

        listener.client.on :error do |e|
          raise Ginseng::GatewayError, (e.message rescue e.to_s)
        end

        listener.client.on :message do |message|
          listener.receive(message)
        end
      end
    rescue => e
      @client = nil
      e.alert
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
