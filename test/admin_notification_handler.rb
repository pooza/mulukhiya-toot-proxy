module MulukhiyaTootProxy
  class AdminNotificationHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('admin_notification')
    end

    def test_hook_pre_toot
      @handler.clear
      @handler.hook_pre_toot({'status' => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => "周知を含むトゥートのテスト\n#notify"})
      assert_equal(@handler.result[:entries], [true])
    end
  end
end
