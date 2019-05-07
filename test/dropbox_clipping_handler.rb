module MulukhiyaTootProxy
  class DropboxClippingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('dropbox_clipping')
    end

    def test_exec
      @handler.exec({'status' => Time.now.to_s})
      assert_nil(@handler.result)
      sleep(1)

      @handler.exec({'status' => "#{Time.now} \#dropbox"})
      assert_equal(@handler.result[:entries].count, 1)
      sleep(1)
    end
  end
end
