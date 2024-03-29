module Mulukhiya
  class MeisskeyListener < MisskeyListener
    def self.sender(payload)
      return Environment.account_class.get(id: payload.dig('body', 'user', 'id'))
    rescue => e
      e.log
    end

    def self.start
      EM.run do
        listener = MeisskeyListener.new

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
