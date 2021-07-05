module Mulukhiya
  class MailAlertHandlerTest < TestCase
    def setup
      @handler = Handler.create('mail_alert')
    end

    def test_handle_alert
      raise Ginseng::RenderError, 'Renderエラーが起きたというテスト。'
    rescue Ginseng::RenderError => e
      @handler.handle_alert(e)
      assert_kind_of(Ginseng::RenderError, @handler.error)
    end
  end
end
