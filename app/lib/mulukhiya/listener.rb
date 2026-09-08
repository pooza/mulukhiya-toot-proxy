require 'faye/websocket'

module Mulukhiya
  class Listener
    include Package
    include SNSMethods

    attr_reader :client, :uri, :sns

    def verify_peer?
      return config["/#{Environment.controller_name}/streaming/verify_peer"]
    end

    # ⚠⚠ **ここに渡る値は env ではなく `ca_file` 相当 (#4586)。**
    # `SSL_CERT_FILE` として読まれるぶんには存在しないパスは無害だが、
    # `Faye::WebSocket::Client` の `tls[:root_cert_file]` へ渡すと
    # `SSL_CTX_load_verify_file` が即座に `OpenSSL::SSL::SSLError` で落ちる。
    # **実在するものだけ通す。**nil なら OS の CA ストアに倒れ、`verify_peer` は効く。
    #
    # ⚠ **`rescue` は「未設定」だけに絞る。**裸の `rescue` は未設定・typo・型違いを
    # 同じ穴に落として区別できなくしていた。
    #
    # **2026-09-09 の実機確認（shallu 本番）**: `cert/cacert.pem` は存在せず、
    # ginseng-core 側が `File.exist?` で守っている（#512 / #548）ので
    # `SSL_CERT_FILE` は `HTTP.new` の後でも nil のまま。⚠ **つまり現状は常に nil が
    # 渡っており、検証は OS の CA ストアで効いている**（「検証が素通り」ではない）。
    # ⚠⚠ **これは潜在的な地雷で、`rake cert:update` を打った瞬間に経路が生きる。**
    def root_cert_file
      return readable_cert_file(config[root_cert_file_key], :config)
    rescue Ginseng::ConfigError
      return readable_cert_file(ENV.fetch('SSL_CERT_FILE', nil), :env)
    end

    def root_cert_file_key
      return "/#{Environment.controller_name}/streaming/root_cert_file"
    end

    # ⚠ **黙って nil に倒さない。**運用者が指定した CA が落ちたことに気付けないと、
    # 「検証しているつもりで OS のストアを見ている」状態が無音で続く。
    def readable_cert_file(path, source)
      return nil if path.blank?
      return path if File.exist?(path)
      logger.error(error: 'root_cert_file not found', source:, path: path.to_s)
      return nil
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
