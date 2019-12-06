module MulukhiyaTootProxy
  class FavGrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @config = Config.instance
      @handler = Handler.create('fav_growi_clipping')
      @account = Account.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return if Environment.ci?
      return if @handler.disable?

      @handler.clear
      @handler.handle_post_fav('id' => @toot.id)
      assert(MastodonURI.parse(@handler.result[:entries].first[:url]).id.positive?)
    end
  end
end
