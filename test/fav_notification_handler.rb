module Mulukhiya
  class FavNotificationHandlerTest < TestCase
    def setup
      @handler = Handler.create('fav_notification')
      return unless handler?
      @account = Environment.test_account
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return unless handler?

      @handler.clear
      @handler.handle_post_fav('id' => 0)
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_fav('id' => @toot.id)
      assert(@handler.result[:entries].first[:status_id].positive?)
      assert_equal(@handler.result[:entries].first[:status_id], @toot.id)
    end
  end
end
