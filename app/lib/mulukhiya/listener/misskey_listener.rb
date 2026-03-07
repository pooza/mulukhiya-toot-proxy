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
      return Event.new(:mention, {sns:}).dispatch(payload)
    end

    def handle_followed(payload)
      return Event.new(:follow, {sns:}).dispatch(payload)
    end

    def handle_announcement_created(payload)
      sleep(Worker.create(:announcement).worker_config(:interval, :seconds))
      return AnnouncementWorker.perform_async
    end

    def self.sender(payload)
      return Environment.account_class[
        payload.dig('body', 'user', 'id') || payload.dig('body', 'id'),
      ]
    rescue => e
      e.log
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
