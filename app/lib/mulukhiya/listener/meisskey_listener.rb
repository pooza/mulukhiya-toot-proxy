module Mulukhiya
  class MeisskeyListener < MisskeyListener
    def self.sender(payload)
      return Environment.account_class.get(id: payload.dig('body', 'user', 'id'))
    rescue => e
      logger.error(error: e)
    end

    def self.verify_peer
      return config['/meisskey/streaming/verify_peer']
    end

    def self.start
      EM.run do
        listener = MeisskeyListener.new

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
  end
end
