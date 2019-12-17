module MulukhiyaTootProxy
  class ResultNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('result_notification')
    end

    def test_handle_post_toot
      @handler.clear
      @handler.handle_post_toot({message_field => 'ふつうのトゥート。'})
      assert_nil(@handler.result)
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
