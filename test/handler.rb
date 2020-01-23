module Mulukhiya
  class HandlerTest < TestCase
    def test_disable?
      Environment.controller_class.events.each do |event|
        Handler.all(event) do |handler|
          assert_boolean(handler.disable?)
        end
      rescue Ginseng::ConfigError
        next
      end
    end

    def test_create_parser
      Environment.controller_class.events.each do |event|
        Handler.all(event) do |handler|
          parser = handler.create_parser('command: user_config')
          assert_kind_of(StatusParser, parser)
          assert_equal(parser.command, 'user_config')
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
