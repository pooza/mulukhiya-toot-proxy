module Mulukhiya
  class BookmarkDropboxClippingHandlerTest < TestCase
    def setup
      @handler = Handler.create('bookmark_dropbox_clipping')
      return unless handler?
      @account = Environment.test_account
      @status = @account.recent_status
    end

    def test_handle_post_boost
      return unless handler?
      @handler.clear
      @handler.handle_post_bookmark('id' => @status.id)
      assert_kind_of(Ginseng::URI, Ginseng::URI.parse(@handler.result[:entries].first[:url]))
    end
  end
end
