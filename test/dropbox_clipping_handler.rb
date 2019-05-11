module MulukhiyaTootProxy
  class DropboxClippingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('dropbox_clipping')
    end

    def test_handle_post_toot
      @handler.clear
      @handler.handle_post_toot({'status' => Time.now.to_s})
      assert_nil(@handler.result)
      sleep(1)

      @handler.clear
      @handler.handle_post_toot({'status' => "#{Time.now} \#dropbox"})
      assert(@handler.result[:entries].present?)
      sleep(1)
    end
  end
end
