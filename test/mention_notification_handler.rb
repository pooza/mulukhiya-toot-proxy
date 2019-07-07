module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def setup
      return if Environment.ci?
      @config = Config.instance
      @handler = Handler.create('mention_notification')
      @account = Account.new({token: @config['/test/token']})
    end

    def test_handle_post_toot
      return if Environment.ci?

      @handler.clear
      @handler.handle_post_toot({'status' => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({'status' => "通知を含むトゥートのテスト\n @#{@account.username}"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
