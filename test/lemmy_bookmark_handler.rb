module Mulukhiya
  class LemmyBookmarkHandlerTest < TestCase
    def disable?
      return true unless controller_class.lemmy?
      return true unless (account.lemmy rescue nil)
      return super
    end

    def setup
      @handler = Handler.create(:lemmy_bookmark)
      @status = account.recent_status
    end

    def test_handle_post_bookmark
      @handler.handle_post_bookmark(status_key => @status.id)

      assert_kind_of(Ginseng::URI, Ginseng::URI.parse(@handler.debug_info[:result].first[:url]))
    end
  end
end
