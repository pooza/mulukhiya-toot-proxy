module Mulukhiya
  class ResultNotificationHandlerTest < TestCase
    def setup
      @handler = Handler.create(:result_notification)
    end

    def test_handle_post_toot
      @handler.handle_post_toot(status_field => 'ふつうのトゥート。')

      assert_nil(@handler.debug_info)
    end
  end
end
