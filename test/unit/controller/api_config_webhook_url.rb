module Mulukhiya
  # GET /mulukhiya/api/config の `webhook.url` は nullable (#4487 / #4537)。
  #
  # ⚠ 本物の Account は DB を掴むのでダブルを差す。実サーバーに依存させると
  # DBMS の無い環境でケースごと omit され、この判定が一度も走らない。
  class APIConfigWebhookURLTest < TestCase
    WebhookDouble = Struct.new(:available, :url) do
      def available?
        return available
      end

      # トークンが無いと digest を作れず ConfigError になる、を模す。
      def uri
        raise Ginseng::ConfigError, 'token not found' unless available
        return url
      end
    end

    def setup
      @controller = APIController.new!
    end

    def test_returns_url_when_token_present
      stub_webhook(WebhookDouble.new(true, 'https://example.com/mulukhiya/webhook/deadbeef'))

      assert_equal(
        'https://example.com/mulukhiya/webhook/deadbeef',
        @controller.send(:webhook_url),
      )
    end

    # ⚠ `available?` を見ずに uri を触ると ConfigError → 500 に化ける。
    # クライアントには null を返す（Webhook 未利用として扱わせる）。
    def test_returns_nil_without_token
      stub_webhook(WebhookDouble.new(false, nil))

      assert_nil(@controller.send(:webhook_url))
    end

    private

    def stub_webhook(webhook)
      account = Struct.new(:webhook).new(webhook)
      sns = Struct.new(:account).new(account)
      @controller.define_singleton_method(:sns) {sns}
    end
  end
end
