module MulukhiyaTootProxy
  class WebhookURLCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('webhook_url_command')
    end

    def test_exec
      @handler.exec({'status' => ''})
      assert_nil(@handler.result)
    end
  end
end
