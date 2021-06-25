module Mulukhiya
  class SlackAlertHandlerTest < TestCase
    def setup
      @handler = Handler.create('slack_alert')
    end

    def test_handle_alert
      @handler.clear
      raise Ginseng::AuthError, '認証エラーが起きたテイのテスト。'
    rescue Ginseng::AuthError => e
      assert_kind_of(Ginseng::AuthError, @handler.handle_alert(e))
    end
  end
end
