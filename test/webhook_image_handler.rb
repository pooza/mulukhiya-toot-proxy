module Mulukhiya
  class WebhookImageHandlerTest < TestCase
    def setup
      @handler = Handler.create(:webhook_image)
    end

    def test_handle_pre_webhook
      @handler.handle_pre_webhook(
        status_field => '武田信玄',
        'attachments' => [
          {'image_url' => 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'},
          {'image_url' => 'https://images-na.ssl-images-amazon.com/images/I/21VK3xpmERL._AC_.jpg'},
        ],
      )
      result = @handler.debug_info[:result]
      assert(result.member?(source_url: 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg'))
      assert(result.member?(source_url: 'https://images-na.ssl-images-amazon.com/images/I/21VK3xpmERL._AC_.jpg'))
    end
  end
end
