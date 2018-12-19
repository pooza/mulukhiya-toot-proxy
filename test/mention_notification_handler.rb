module MulukhiyaTootProxy
  class MentionNotificationHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance
      handler = Handler.create('mention_notification')
      handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
      handler.exec({'status' => 'ふつうのトゥート。'})
      assert_equal(handler.result, 'MentionNotificationHandler,0')
      handler.exec({'status' => "通知を含むトゥートのテスト\n #{config['/test/account']}"})
      assert_equal(handler.result, 'MentionNotificationHandler,1')
    end
  end
end
