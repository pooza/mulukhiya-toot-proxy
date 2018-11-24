module MulukhiyaTootProxy
  class GrowiClippingHandlerTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      @handler = Handler.create('growi_clipping')
      @handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
    end

    def test_exec
      @handler.exec({'status' => "#{Time.now}"})
      assert_equal(@handler.result, 'GrowiClippingHandler,0')

      @handler.exec({'status' => "#{Time.now} \#growi"})
      assert_equal(@handler.result, 'GrowiClippingHandler,1')
    end
  end
end
