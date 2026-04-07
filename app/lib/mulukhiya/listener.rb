require 'faye/websocket'

module Mulukhiya
  class Listener
    include Package
    include SNSMethods

    attr_reader :client, :uri, :sns

    def verify_peer?
      return config["/#{Environment.controller_name}/streaming/verify_peer"]
    end

    def root_cert_file
      return config["/#{Environment.controller_name}/streaming/root_cert_file"]
    rescue
      return ENV.fetch('SSL_CERT_FILE', nil)
    end

    def keepalive
      return config['/websocket/keepalive']
    end

    def underscore
      return self.class.to_s.split('::').last.sub(/Listener$/, '').underscore
    end

    def log(message)
      logger.info({listener: underscore}.merge(message))
    end

    def self.start
      @stopping = false
      @retry_count = 0
      setup_signal_handlers
      begin
        run_event_loop
      rescue => e
        return if @stopping
        handle_retry(e)
        return if @stopping
        retry
      end
    end

    def self.run_event_loop
      EM.run do
        listener = new
        listener.client.on :close do
          raise 'An unintended disconnection has occurred.'
        end
        listener.client.on :error do |e|
          raise Ginseng::GatewayError, (e.message rescue e.to_s)
        end
        listener.client.on :message do |message|
          @retry_count = 0
          touch_last_event
          listener.receive(message)
        end
      end
    end

    def self.handle_retry(err)
      @client = nil
      err.log
      @retry_count += 1
      if @retry_count >= config['/websocket/retry/max_count']
        logger.error(message: 'Max retries exceeded', count: @retry_count)
        exit 1
      end
      logger.info(message: 'Retrying', count: @retry_count, delay: retry_delay)
      interruptible_sleep(retry_delay)
    end

    def self.setup_signal_handlers
      ['TERM', 'INT'].each do |sig|
        Signal.trap(sig) do
          @stopping = true
          EM.stop if EM.reactor_running?
        end
      end
    end

    def self.retry_delay
      base = config['/websocket/retry/seconds']
      max = config['/websocket/retry/max_seconds']
      return [base * (2**(@retry_count - 1)), max].min
    end

    def self.interruptible_sleep(seconds)
      seconds.to_i.times do
        return if @stopping
        sleep(1)
      end
    end

    def self.touch_last_event
      Redis.new.set('listener:last_event', Time.now.to_i)
    rescue
      nil
    end

    private

    def initialize
      return unless @sns = info_agent_service
      @uri = @sns.streaming_uri
      @client = Faye::WebSocket::Client.new(uri.to_s, [], {
        tls: {
          verify_peer: verify_peer?,
          root_cert_file:,
          logger:,
        },
        ping: keepalive,
      })
      log(method: __method__, url: uri.to_s)
    end

    def create_method_name(name)
      return "handle_#{name.gsub(/[^[:word:]]+/, '_')}".underscore
    end
  end
end
