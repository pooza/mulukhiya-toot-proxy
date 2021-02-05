module Mulukhiya
  class SlackAlertHandlerTest < TestCase
    def setup
      @handler = Handler.create('slack_alert')
    end

    def test_handle_alert
      return unless handler?

      begin
        @handler.clear
        raise Ginseng::AuthError, 'だめです。'
      rescue Ginseng::AuthError => e
        assert_kind_of(Ginseng::AuthError, @handler.handle_alert(e))
      end
    end
  end
end
