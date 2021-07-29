module Mulukhiya
  class MeisskeyListener < MisskeyListener
    def self.sender(payload)
      return Environment.account_class.get(id: payload.dig('body', 'user', 'id'))
    rescue => e
      logger.error(error: e)
    end

    def self.start
      EM.run do
        listener = MeisskeyListener.new

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
  end
end
