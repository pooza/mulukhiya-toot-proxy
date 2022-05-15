module Mulukhiya
  class LineAlertHandlerTest < TestCase
    def disable?
      return true unless LineService.config?
      return super
    end

    def setup
      @handler = Handler.create(:line_alert)
    end

    def test_handle_alert
      raise Ginseng::AuthError, '認証エラーが起きたテイのテスト。'
    rescue Ginseng::AuthError => e
      @handler.handle_alert(e)
      assert_kind_of(Ginseng::AuthError, @handler.error)
    end
  end
end
