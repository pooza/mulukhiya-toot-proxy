module Mulukhiya
  class MastodonListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)
      method_name = create_method_name(payload['event'])
      if payload['event'] == 'notification'
        payload = JSON.parse(payload['payload'])
        method_name = create_method_name("#{payload['type']}_notification")
      end
      return send(method_name.to_sym, payload)
    rescue NoMethodError
      logger.info(class: self.class.to_s, method: method_name, message: 'method unimplemented')
    rescue => e
      e.log(payload: (payload rescue message.data))
    end

    def handle_mention_notification(payload)
      Event.new(:mention, {sns:}).dispatch(payload)
    end

    def handle_follow_notification(payload)
      Event.new(:follow, {sns:}).dispatch(payload)
    end

    def handle_announcement(payload)
      sleep(Worker.create(:announcement).worker_config('interval/seconds'))
      AnnouncementWorker.perform_async
    end

    def self.sender(payload)
      return Environment.account_class[payload.dig('account', 'id')]
    rescue => e
      e.log
    end

    def self.start
      EM.run do
        listener = MastodonListener.new

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
  end
end
