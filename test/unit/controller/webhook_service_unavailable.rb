module Mulukhiya
  # 機能が無効・未設定のときに 503 を返すこと (5.35.0 リリース前レビューの赤)。
  #
  # ⚠⚠ **`Ginseng::ServiceUnavailableError` は存在しない定数だった。**
  # `WebhookController` が 2 箇所でそれを `raise` しており、到達すると
  # `NameError` になる。`StandardError#status` は refine で 500 を返すので、
  # クライアントには **500 +「uninitialized constant」**が返り、さらに
  # alert 側へ倒れて**未認証の第三者が管理者アラートを撃てる**状態だった。
  class WebhookServiceUnavailableTest < TestCase
    def test_constant_exists
      assert_kind_of(Class, ServiceUnavailableError)
      assert_operator(ServiceUnavailableError, :<, Ginseng::Error)
    end

    def test_status_is_service_unavailable
      assert_equal(503, ServiceUnavailableError.new('x').status)
    end

    # ⚠ 設定が無いのは運用者が知っていれば足りる話で、外部から叩かれるたびに
    # 管理者へメール / Slack を飛ばす種類の事象ではない（#4594 と同じ判断）。
    def test_is_not_broadcastable
      assert_false(ServiceUnavailableError.new('x').broadcastable?)
    end

    # ⚠ **旧コードは NameError になっていた。**同じ名前で raise していないことを見る。
    def test_ginseng_namespace_is_not_used
      source = File.read(File.join(Environment.dir, 'app/lib/mulukhiya/controller/webhook_controller.rb'))

      assert_not_match(/raise Ginseng::ServiceUnavailableError/, source)
    end

    # 4xx ではないので alert 抑止には乗らない（運用者には見える）。
    def test_is_not_treated_as_client_error
      assert_false(MisskeyController.new!.client_error?(ServiceUnavailableError.new('x')))
    end
  end
end
