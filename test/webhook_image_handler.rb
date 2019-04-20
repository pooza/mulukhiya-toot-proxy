module MulukhiyaTootProxy
  class WebhookImageHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('webhook_image')
      @handler.mastodon = Mastodon.new(@config['/instance_url'], @config['/test/token'])
    end

    def test_exec
      @handler.exec({
        'status' => '武田信玄',
        'attachments' => [
          {'image_url' => 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'},
          {'image_url' => 'https://m.media-amazon.com/images/I/81S31QX87tL._SS500_.jpg'},
        ],
      })
      assert_equal(@handler.result[:entries], ['https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'])
    end
  end
end
