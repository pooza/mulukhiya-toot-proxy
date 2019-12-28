module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('mention_notification')
      return unless handler?
      @account = Environment.account_class.get(token: @config['/test/token'])
    end

    def test_handle_post_toot
      return unless handler?

      @handler.clear
      @handler.handle_post_toot({message_field => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({message_field => "通知を含むトゥートのテスト\n @#{@account.username}"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
