module MulukhiyaTootProxy
  class WebhookURLCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('webhook_url_command')
    end

    def test_exec
      @handler.clear
      @handler.exec({'status' => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.exec({'status' => "command: webhook_url\n"})
      assert(@handler.result.present?)
    end
  end
end
