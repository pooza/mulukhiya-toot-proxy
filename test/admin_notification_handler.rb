module MulukhiyaTootProxy
  class AdminNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('admin_notification')
    end

    def test_exec
      @handler.exec({'status' => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.exec({'status' => "周知を含むトゥートのテスト\n#notify"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
