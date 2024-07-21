module Mulukhiya
  class NextcloudBookmarkHandlerTest < TestCase
    def disable?
      return true unless controller_class.nextcloud?
      return true unless (account.nextcloud rescue nil)
      return true unless account.nextcloud.ping
      return super
    end

    def setup
      @handler = Handler.create(:nextcloud_bookmark)
      @status = account.recent_status
    end

    def test_handle_post_bookmark
      @handler.handle_post_bookmark(status_key => @status.id)

      assert_kind_of(Ginseng::URI, Ginseng::URI.parse(@handler.debug_info[:result].first[:url]))
    end
  end
end
