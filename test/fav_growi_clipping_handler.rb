module MulukhiyaTootProxy
  class FavGrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      return unless Postgres.config?
      @config = Config.instance
      @handler = Handler.create('fav_growi_clipping')
      @account = Environment.account_class.get(token: @config['/test/token'])
      @toot = @account.recent_toot
    end

    def test_handle_post_boost
      return unless Postgres.config?
      return if @handler.disable?

      @handler.clear
      @handler.handle_post_fav('id' => @toot.id)
      assert(MastodonURI.parse(@handler.result[:entries].first[:url]).id.positive?)
    end
  end
end
