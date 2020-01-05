module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < TestCase
    def setup
      @handler = Handler.create('mention_notification')
      return unless handler?
      @account = Environment.test_account
    end

    def test_handle_post_toot
      return unless handler?

      @handler.clear
      @handler.handle_post_toot({status_field => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({status_field => "通知を含むトゥートのテスト\n @#{@account.username}"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
