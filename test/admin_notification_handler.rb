module MulukhiyaTootProxy
  class AdminNotificationHandlerTest < Test::Unit::TestCase
    def test_exec
      config = Config.instance
      handler = Handler.create('admin_notification')
      handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
      handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_equal(handler.result, 'AdminNotificationHandler,1')
    end
  end
end
