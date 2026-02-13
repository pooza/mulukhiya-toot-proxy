module Mulukhiya
  class LineAlertHandlerTest < TestCase
    def setup
      @handler = Handler.create(:line_alert)
    end

    def test_handle_alert
      message = '認証エラーが起きたテイのテスト。'
      raise Ginseng::AuthError, message
    rescue Ginseng::AuthError => e
      @handler.handle_alert(e)

      assert_kind_of(Ginseng::AuthError, @handler.error)
      assert_same(e, @handler.error)
      assert_equal(message, @handler.error.message)
    end
  end
end
