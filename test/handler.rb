module MulukhiyaTootProxy
  class HandlerTest < TestCase
    def setup
      @config = Config.instance
      @config['/tagging/dictionaries'] = [
        {
          'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbzAUsRUuFLO72EgKta020v9OMtxvUtqUcPZNJ3_IMlOo8dRO7tW/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbyy5EQHvhKfm1Lg6Ae4W7knG4BCSkvepJyB6MrzQ8UIxmFfZMJj/exec',
          'type' => 'relative',
        },
      ]
    end

    def test_disable?
      Environment.controller_class.events.each do |event|
        Handler.all(event) do |handler|
          assert_boolean(handler.disable?)
        end
      rescue Ginseng::ConfigError
        next
      end
    end

    def test_exec_all
      return if Handler.create('spotify_url_nowplaying').disable?
      params = {}
      Handler.exec_all(
        :pre_toot,
        {status_field => '#nowplaying https://open.spotify.com/track/3h5LpK0cYVoZgkU1Gukedq', 'visibility' => 'private'},
        params,
      )
      assert(params[:tags].member?('宮本佳那子'))
      assert(params[:tags].member?('福山沙織'))
      assert(params[:tags].member?('井上由貴'))
    end
  end
end
