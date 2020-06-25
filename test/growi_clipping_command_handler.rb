module Mulukhiya
  class GrowiClippingCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('growi_clipping_command')
    end

    def test_handle_toot
      return unless handler?

      @handler.clear
      @handler.handle_toot(status_field => '')
      assert_nil(@handler.debug_info)
      sleep(1)

      @handler.clear
      @handler.handle_toot(status_field => "command: growi_clipping\nurl: https://mstdn.b-shock.org/web/statuses/101125535795976504")
      assert(@handler.debug_info[:result].present?)
      sleep(1)

      @handler.clear
      @handler.handle_toot(status_field => "command: growi_clipping\nurl: https://precure.ml/@pooza/101276312982799462")
      assert(@handler.debug_info[:result].present?)
      sleep(1)
    end
  end
end
