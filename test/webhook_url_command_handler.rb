module MulukhiyaTootProxy
  class WebhookURLCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('webhook_url_command')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({'status' => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => "command: webhook_url\n"})
      assert(@handler.result.present?)
    end
  end
end
