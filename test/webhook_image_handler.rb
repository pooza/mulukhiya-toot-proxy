module MulukhiyaTootProxy
  class WebhookImageHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('webhook_image')
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
