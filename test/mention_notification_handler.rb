module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('mention_notification')
      @account = Mastodon.lookup_token_owner(@config['/test/token'])
    end

    def test_exec
      @handler.clear
      @handler.exec({'status' => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.exec({'status' => "通知を含むトゥートのテスト\n @#{@account['username']}"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
