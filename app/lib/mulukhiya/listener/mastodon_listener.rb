module Mulukhiya
  class MastodonListener < Listener
    def receive(message)
      payload = JSON.parse(message.data)
      method_name = create_method_name(payload['event'])
      if payload['event'] == 'notification'
        payload = JSON.parse(payload['payload'])
        method_name = create_method_name("#{payload['type']}_notification")
      end
      logger.info(class: self.class.to_s, method: method_name)
      return send(method_name.to_sym, payload)
    rescue NoMethodError
      logger.error(class: self.class.to_s, method: method_name, message: 'method undefined')
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
    end

    def handle_mention_notification(payload)
      Event.new(:mention, {sns: sns}).dispatch(payload)
    end

    def handle_follow_notification(payload)
      Event.new(:follow, {sns: sns}).dispatch(payload)
    end

    def handle_announcement(payload)
      sleep(config['/worker/announcement/interval/seconds'])
      AnnouncementWorker.perform_async
    end

    def self.sender(payload)
      return Environment.account_class[payload.dig('account', 'id')]
    rescue => e
      logger.error(error: e)
    end

    def self.start
      EM.run do
        listener = MastodonListener.new

        listener.client.on :close do |e|
          raise Ginseng::GatewayError, (e.message rescue e.to_s)
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
      logger.error(error: e)
      sleep(config['/websocket/retry/seconds'])
      retry
    end
  end
end
