module MulukhiyaTootProxy
  class FavDropboxClippingHandlerTest < TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('fav_dropbox_clipping')
      return unless handler?
      @account = Environment.account_class.get(token: @config['/test/token'])
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
