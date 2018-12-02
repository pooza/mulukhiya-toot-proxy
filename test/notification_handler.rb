module MulukhiyaTootProxy
  class NotificationHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('notification')
      handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_equal(handler.result, 'NotificationHandler,1')
    end
  end
end
