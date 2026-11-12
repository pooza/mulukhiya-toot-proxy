module Mulukhiya
  # ストリーミングのトークンは URL ではなくヘッダで渡す（ginseng-fediverse 8.0.0・#4899）。
  # ⚠ 通信しない。`Faye::WebSocket::Client.new` を差し替えて、渡る options だけを見る。
  class ListenerStreamingHeadersTest < TestCase
    def setup
      @captured = nil
      @protocols = nil
      captured = lambda do |protocols, opts|
        @protocols = protocols
        @captured = opts
      end
      Faye::WebSocket::Client.define_singleton_method(:new) do |_url, protocols = nil, opts = {}|
        captured.call(protocols, opts)
        Object.new
      end
      sns = Struct.new(:streaming_uri, :streaming_headers).new(
        URI.parse('wss://example.com/streaming'),
        {'Authorization' => 'Bearer secret'},
      )
      @listener_class = Class.new(Listener) do
        define_method(:info_agent_service) {sns}
      end
    end

    # 特異メソッドを消せば `Class#new` に戻る。
    def teardown
      Faye::WebSocket::Client.singleton_class.send(:remove_method, :new)
      super
    end

    def test_headers
      listener = @listener_class.new

      assert_equal({'Authorization' => 'Bearer secret'}, @captured[:headers])
      assert_not_include(listener.uri.to_s, 'secret')
      assert_equal([], @protocols)
    end

    # Pleroma 系（Akkoma）は `Authorization` を読まないので、`Sec-WebSocket-Protocol` で渡す（#4901）。
    # 🔴 URL（逆プロキシと listener のログに残る）にもヘッダにも載せない。
    def test_protocols
      sns = Struct.new(:streaming_uri, :streaming_headers, :streaming_protocols).new(
        URI.parse('wss://example.com/api/v1/streaming?stream=user'), {}, ['secret']
      )
      listener_class = Class.new(Listener) do
        define_method(:info_agent_service) {sns}
      end
      listener = listener_class.new

      assert_equal(['secret'], @protocols)
      assert_equal({}, @captured[:headers])
      assert_not_include(listener.uri.to_s, 'secret')
    end
  end
end
