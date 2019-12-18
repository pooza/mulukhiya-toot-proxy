module MulukhiyaTootProxy
  class FavGrowiClippingHandlerTest < HandlerTest
    def setup
      @config = Config.instance
      return unless @handler = Handler.create('fav_growi_clipping')
      return if @handler.nil? || @handler.disable?
      @account = Environment.account_class.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return if @handler.nil? || @handler.disable?
      @handler.clear
      @handler.handle_post_fav('id' => @toot.id)
      assert(MastodonURI.parse(@handler.result[:entries].first[:url]).id.positive?)
    end
  end
end
