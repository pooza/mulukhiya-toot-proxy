module MulukhiyaTootProxy
  class WebhookURLCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('webhook_url_command')
    end

    def test_parse
      assert_nil(@handler.parse(''))
      assert_nil(@handler.parse('123'))
      assert_equal(@handler.parse('{"command": webhook_url}'), {'command' => 'webhook_url'})
      assert_equal(@handler.parse('command: webhook_url'), {'command' => 'webhook_url'})
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
