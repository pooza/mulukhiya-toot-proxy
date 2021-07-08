module Mulukhiya
  class MeisskeyListener < MisskeyListener
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
