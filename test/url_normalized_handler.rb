require 'mulukhiya-toot-proxy/handler/url_normalize'

module MulukhiyaTootProxy
  class UrlNormalizeHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = UrlNormalizeHandler.new
      assert_equal(handler.exec('https://www.google.co.jp/?q=日本語'), 'https://www.google.co.jp/?q=%E6%97%A5%E6%9C%AC%E8%AA%9E')
      assert_equal(handler.result, 'UrlNormalizeHandler,1')
    end
  end
end
