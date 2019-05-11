module MulukhiyaTootProxy
  class URLNormalizeHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('url_normalize')
    end

    def test_handle_pre_toot
      r = @handler.handle_pre_toot({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_equal(@handler.result[:entries], ['https://www.google.co.jp/?q=日本語'])
      assert_equal(r['status'], 'https://www.google.co.jp/?q=%E6%97%A5%E6%9C%AC%E8%AA%9E')
    end
  end
end
