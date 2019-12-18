module MulukhiyaTootProxy
  class GrowiClippingCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('growi_clipping_command')
    end

    def test_handle_post_toot
      return if invalid_handler?

      @handler.clear
      @handler.handle_post_toot({message_field => ''})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.handle_post_toot({message_field => "command: growi_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504"})
      assert(@handler.result[:entries].present?)
      sleep(1)

      @handler.clear
      @handler.handle_post_toot({message_field => "command: growi_clipping\nurl: https://precure.ml/@pooza/101276312982799462"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
