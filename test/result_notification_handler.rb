module MulukhiyaTootProxy
  class ResultNotificationHandlerTest < HandlerTest
    def setup
      @handler = Handler.create('result_notification')
    end

    def test_handle_post_toot
      return if @handler.nil? || @handler.disable?
      @handler.clear
      @handler.handle_post_toot(message_field => 'ふつうのトゥート。')
      assert_nil(@handler.result)
    end
  end
end
