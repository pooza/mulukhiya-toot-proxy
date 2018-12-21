module MulukhiyaTootProxy
  class GrowiClippingCommandHandlerTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      @handler = Handler.create('growi_clipping_command')
      @handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
    end

    def test_exec
      @handler.exec({'status' => ''})
      assert_equal(@handler.result, 'GrowiClippingCommandHandler,0')

      @handler.exec({'status' => "command: growi_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504"})
      assert_equal(@handler.result, 'GrowiClippingCommandHandler,1')
      @handler.exec({'status' => "command: growi_clipping\nurl: https://precure.ml/@pooza/101276312982799462"})
      assert_equal(@handler.result, 'GrowiClippingCommandHandler,2')
    end
  end
end
