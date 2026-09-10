module Mulukhiya
  # `/webhook/:digest` の失敗で、5xx の原文を送信側へ返さないこと（5.37.0 リリース前レビュー）。
  #
  # ⚠⚠ `/:digest` は認証前に任意の digest で叩ける。DB 障害中は `Webhook.create!` が上げる
  # `PG::ConnectionBad: connection to server at "127.0.0.1", port 6432 ...` が、
  # **第三者へそのまま返っていた**（#4694 が添付エラーだけで塞いだものと同じ種類の漏れ）。
  class WebhookErrorBodyTest < TestCase
    def setup
      @controller = WebhookController.allocate
    end

    # 🔴 **本体。**5xx は内部の接続先を含む原文を返さない。
    def test_server_error_message_is_not_leaked
      error = Sequel::DatabaseConnectionError.new(
        'PG::ConnectionBad: connection to server at "127.0.0.1", port 6432 failed',
      )

      assert_equal('Internal Server Error', message_for(error))
    end

    # 未知の digest は送信側が対処できる情報なので通す。
    def test_not_found_message_is_passed_through
      error = Ginseng::NotFoundError.new('Webhook not found (digest: 0123456789ab...)')

      assert_equal('Webhook not found (digest: 0123456789ab...)', message_for(error))
    end

    # ⚠ 503 でも、自前で文言を決めている「無効・未設定」は通す。
    def test_service_unavailable_message_is_passed_through
      assert_equal('Webhook is not enabled', message_for(ServiceUnavailableError.new('Webhook is not enabled')))
    end

    private

    def message_for(error)
      return @controller.send(:error_body_message, error)
    end
  end
end
