module MulukhiyaTootProxy
  class URLNormalizeHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('url_normalize')
      assert_equal(handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})['status'], 'https://www.google.co.jp/?q=%E6%97%A5%E6%9C%AC%E8%AA%9E')
      assert_equal(handler.result, 'URLNormalizeHandler,1')
    end
  end
end
