module Mulukhiya
  class HandlerTest < TestCase
    def setup
      @handler = Handler.create('spotify_url_nowplaying')
    end

    def test_all
      Environment.controller_class.events.each do |event|
        Handler.all(event) do |handler|
          assert_boolean(handler.disable?)
          assert_boolean(handler.verbose?)
        end
      rescue Ginseng::ConfigError
        next
      end
    end

    def test_dispatch
      return unless handler?
      params = {}
      Handler.dispatch(
        :pre_toot,
        {status_field => '#nowplaying https://open.spotify.com/track/3h5LpK0cYVoZgkU1Gukedq', 'visibility' => 'private'},
        params,
      )
      assert(params[:reporter].tags.member?('宮本佳那子'))
      assert(params[:reporter].tags.member?('福山沙織'))
      assert(params[:reporter].tags.member?('井上由貴'))
    end
  end
end
