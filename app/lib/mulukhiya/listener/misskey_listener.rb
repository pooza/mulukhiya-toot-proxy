module Mulukhiya
  class MisskeyListener < Listener
    def receive(message)
      data = JSON.parse(message.data)
      payload = data['body']
      method_name = create_method_name(payload['type'] || data['type'])
      return send(method_name.to_sym, payload)
    rescue NoMethodError
      log(method: method_name, message: 'method unimplemented')
    rescue => e
      e.log(payload: (payload rescue message.data))
    end

    def handle_mention(payload)
      Event.new(:mention, {sns:}).dispatch(payload)
    end

    def handle_followed(payload)
      Event.new(:follow, {sns:}).dispatch(payload)
    end

    def handle_announcement_created(payload)
      sleep(Worker.create(:announcement).worker_config(:interval, :seconds))
      AnnouncementWorker.perform_async
    end

    def self.sender(payload)
      return Environment.account_class[
        payload.dig('body', 'user', 'id') || payload.dig('body', 'id'),
      ]
    rescue => e
      e.log
    end

    def self.start
      EM.run do
        listener = MisskeyListener.new

        listener.client.on :close do
          raise 'An unintended disconnection has occurred.'
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
      e.log
      sleep(config['/websocket/retry/seconds'])
      retry
    end

    private

    def initialize
      super
      client.send(type: 'connect', body: {channel: 'main', id: 'main'})
      client.send(type: 'connect', body: {channel: 'homeTimeline', id: 'home'})
      client.send(type: 'connect', body: {channel: 'localTimeline', id: 'local'})
    end
  end
end
