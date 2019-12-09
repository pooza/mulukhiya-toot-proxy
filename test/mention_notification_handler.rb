module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def setup
      return unless Postgres.config?
      @config = Config.instance
      @handler = Handler.create('mention_notification')
      @account = Account.get(token: @config['/test/token'])
    end

    def test_handle_post_toot
      return unless Postgres.config?
      return if @handler.disable?

      @handler.clear
      @handler.handle_post_toot({'status' => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_post_toot({'status' => "通知を含むトゥートのテスト\n @#{@account.username}"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
