module Mulukhiya
  # `paired` の 2 本目が落ちても、リトライ・再認証で回復できる 4xx は
  # クライアントへそのまま返す (#4657 の 1)。
  #
  # ⚠⚠ **従来は 2 本目の「あらゆる」4xx を 502 へ付け替えていた。**上流の
  # レート制限 (429) やその瞬間のトークン失効 (401) までが
  # `internal fetch failed` になり、⚠ **capsicum は 429/401 として扱えず
  # リトライやトークン再取得の導線に載せられなかった**（うえに Sentry alert も立つ）。
  class PairedFetchClientErrorTest < TestCase
    ResponseDouble = Struct.new(:code, :body)

    def setup
      @controller = MastodonController.new!
    end

    # ⚠ **リトライで回復する。**429 は 2 本目だけに当たるのが普通。
    def test_rate_limit_is_passed_through
      error = gateway_error(429)

      assert_equal(error, raised(error, paired: true))
    end

    # ⚠ **再認証で回復する。**1 本目と 2 本目の間にトークンが切れうる。
    def test_expired_token_is_passed_through
      error = gateway_error(401)

      assert_equal(error, raised(error, paired: true))
    end

    # ⚠⚠ **これは付け替えたまま。**1 本目が 200 なのに 2 本目が 404 は
    # **#4621 の症状そのもの**で、クライアントには作れない非対称。
    def test_asymmetric_not_found_is_still_internal
      assert_kind_of(InternalGatewayError, raised(gateway_error(404), paired: true))
    end

    # 5xx は paired かどうかに関わらず内部の失敗。
    def test_server_error_is_internal_regardless_of_pairing
      assert_kind_of(InternalGatewayError, raised(gateway_error(502), paired: true))
      assert_kind_of(InternalGatewayError, raised(gateway_error(502), paired: false))
    end

    # ⚠ 1 本目（`paired: false`）の 4xx は従来どおり透過。429 / 401 も同じ。
    def test_first_fetch_client_errors_are_untouched
      [401, 404, 429].each do |status|
        error = gateway_error(status)

        assert_equal(error, raised(error, paired: false), "status #{status}")
      end
    end

    private

    # `fetch_internal` を通したときに最終的に上がる例外を返す。
    # ⚠ ブロックを渡すと `define_singleton_method` の中の `yield` が
    # 分かりにくいので、上げたい例外をそのまま受け取る。
    def raised(error, paired:)
      sns = Object.new
      sns.define_singleton_method(:fetch_status) {|_id, _params| raise error}
      @controller.instance_variable_set(:@sns, sns)
      @controller.send(:fetch_internal, :fetch_status, '1', {}, paired:)
      raise 'not raised'
    rescue Ginseng::GatewayError => e
      return e
    end

    def gateway_error(status)
      error = Ginseng::GatewayError.new("Bad response #{status}")
      error.response = ResponseDouble.new(status, '{}')
      return error
    end
  end

  # 内部読みの失敗の文言に内部情報を混ぜない (#4657 の 2)。
  #
  # ⚠⚠ **`handle_gateway_error` は別の分岐で「モロヘイヤ内部の例外メッセージを
  # 混ぜてはいけない（内部情報の露出）」と明記していた**のに、この経路だけ
  # `{"error":"internal fetch failed (fetch_status): Bad response 404"}` を返していた。
  class InternalGatewayErrorMessageTest < TestCase
    ResponseDouble = Struct.new(:code, :body)

    def setup
      @controller = MastodonController.new!
      @renderer = Ginseng::Web::JSONRenderer.new
      @controller.instance_variable_set(:@renderer, @renderer)
    end

    def test_client_sees_no_internal_details
      @controller.handle_gateway_error(wrapped)
      body = @renderer.message.is_a?(Hash) ? @renderer.message : JSON.parse(@renderer.message.to_s)
      message = body[:error] || body['error']

      assert_equal('internal fetch failed', message)
      assert_not_match(/fetch_status/, message)
      assert_not_match(/Bad response/, message)
      assert_not_match(/404/, message)
    end

    # ⚠ **ログ側では失われない。**ラベルと上流のメッセージは `message` に残るので、
    # `e.alert` / `e.log` から切り分けに必要な情報は消えない。
    def test_log_keeps_the_label_and_upstream_message
      error = wrapped

      assert_match(/fetch_status/, error.message)
      assert_match(/Bad response 404/, error.message)
    end

    # 既定（`ForeignGatewayError`）は従来どおりメッセージそのまま。
    def test_default_client_message_is_unchanged
      source = Ginseng::GatewayError.new('Bad response 404')

      assert_equal('Bad response 404', ForeignGatewayError.wrap(source).client_message)
    end

    private

    def wrapped
      source = Ginseng::GatewayError.new('Bad response 404')
      source.response = ResponseDouble.new(404, '{}')
      return InternalGatewayError.wrap(source, :fetch_status)
    end
  end
end
