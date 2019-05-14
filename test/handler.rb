module MulukhiyaTootProxy
  class HandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_all
      Handler.all do |handler|
        assert(handler.is_a?(Handler))
      end
    end

    def test_exec_all
      return if Handler.create('spotify_url_nowplaying').disable?
      params = {}
      Handler.exec_all(
        :pre_toot,
        {'status' => '#nowplaying https://open.spotify.com/track/3h5LpK0cYVoZgkU1Gukedq', 'visibility' => 'private'},
        params,
      )
      assert(params[:tags].member?('宮本佳那子'))
      assert(params[:tags].member?('福山沙織'))
      assert(params[:tags].member?('井上由貴'))
    end
  end
end
