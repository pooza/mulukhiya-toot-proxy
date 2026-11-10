module Mulukhiya
  # ストリーミングのトークンは URL ではなくヘッダで渡す（ginseng-fediverse 8.0.0・#4899）。
  # ⚠ 通信しない。`Faye::WebSocket::Client.new` を差し替えて、渡る options だけを見る。
  class ListenerStreamingHeadersTest < TestCase
    def setup
      @captured = nil
      captured = ->(opts) {@captured = opts}
      Faye::WebSocket::Client.define_singleton_method(:new) do |_url, _protocols = nil, opts = {}|
        captured.call(opts)
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
    end
  end
end
