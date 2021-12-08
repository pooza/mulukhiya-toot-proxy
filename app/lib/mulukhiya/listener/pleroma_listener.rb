module Mulukhiya
  class PleromaListener < MastodonListener
    def self.sender(payload)
      return Environment.account_class.get(acct: payload.dig('account', 'fqn'))
    rescue => e
      logger.error(error: e)
    end

    def self.start
      EM.run do
        listener = PleromaListener.new

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
      Event.new(:alert).dispatch(e)
      logger.error(error: e)
      sleep(config['/websocket/retry/seconds'])
      retry
    end
  end
end
