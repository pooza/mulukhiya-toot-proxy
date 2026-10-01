module Mulukhiya
  # 利用者へ返す例外メッセージから 5xx の原文を外す (#4724)。
  #
  # ⚠⚠ OAuth state の取り出し失敗を上げるようにしたので、`/oauth/callback` と
  # `/spotify/auth` へ Redis の例外が届くようになった。原文は接続先を含むので、
  # そのまま返すと内部の構成が漏れる。
  class PublicErrorMessageTest < TestCase
    def setup
      @controller = UIController.new!
    end

    def test_client_error_keeps_the_message
      assert_equal('Missing state', message(Ginseng::AuthError.new('Missing state')))
    end

    def test_server_error_is_masked
      assert_equal('Internal Server Error', message(Ginseng::GatewayError.new('Bad response 502 from 10.0.0.1')))
    end

    # ⚠ 本丸。`status` を持たない例外（Redis の接続エラー等）の原文を出さない。
    def test_statusless_error_is_masked
      error = RuntimeError.new('Connection refused - connect(2) for 127.0.0.1:6379')

      assert_equal('Internal Server Error', message(error))
    end

    private

    def message(error)
      return @controller.send(:public_error_message, error)
    end
  end
end
