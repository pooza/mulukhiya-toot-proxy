module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
    end

    def test_exec
      handler = Handler.create('mention_notification')
      handler.mastodon = Mastodon.new(@config['/instance_url'], @config['/test/token'])
      handler.exec({'status' => 'ふつうのトゥート。'})
      assert_equal(handler.summary, 'MentionNotificationHandler,0')

      account = Mastodon.lookup_token_owner(@config['/test/token'])
      assert(account.is_a?(Hash))
      handler.exec({'status' => "通知を含むトゥートのテスト\n @#{account['username']}"})
      assert_equal(handler.summary, 'MentionNotificationHandler,1')
    end
  end
end
