module Mulukhiya
  class BookmarkDropboxClippingHandlerTest < TestCase
    def setup
      @handler = Handler.create('bookmark_dropbox_clipping')
      return unless handler?
      @account = Environment.test_account
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return unless handler?
      @handler.clear
      @handler.handle_post_fav('id' => @toot.id)
      assert(MastodonURI.parse(@handler.result[:entries].first[:url]).id.positive?)
    end
  end
end
