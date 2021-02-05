module Mulukhiya
  class MailAlertHandlerTest < TestCase
    def setup
      @handler = Handler.create('mail_alert')
    end

    def test_handle_alert
      return unless handler?

      begin
        @handler.clear
        raise Ginseng::RenderError, 'テンプレが腐ってるから書き直せ。'
      rescue Ginseng::RenderError => e
        assert_kind_of(Ginseng::RenderError, @handler.handle_alert(e))
      end
    end
  end
end
