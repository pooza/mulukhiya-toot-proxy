module MulukhiyaTootProxy
  class AdminNotificationHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance
      handler = Handler.create('admin_notification')
      handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
      handler.exec({'status' => 'ふつうのトゥート。'})
      assert_equal(handler.result, 'AdminNotificationHandler,0')
      handler.exec({'status' => '周知を含むトゥート。 #notify'})
      assert_equal(handler.result, 'AdminNotificationHandler,1')
    end
  end
end
