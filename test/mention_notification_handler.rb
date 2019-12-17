module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('mention_notification')
      return if @handler.disable?
      @account = Environment.account_class.get(token: @config['/test/token'])
    end

    def test_handle_post_toot
      return if @handler.disable?

      @handler.clear
      @handler.handle_post_toot({message_field => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({message_field => "通知を含むトゥートのテスト\n @#{@account.username}"})
      assert_equal(@handler.result[:entries], [true])
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
