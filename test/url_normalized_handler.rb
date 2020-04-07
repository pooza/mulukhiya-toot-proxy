module Mulukhiya
  class URLNormalizeHandlerTest < TestCase
    def setup
      @handler = Handler.create('url_normalize')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp/?q=日本語')
      assert_equal(@handler.summary[:result].first, rewrited_url: 'https://www.google.co.jp/?q=%E6%97%A5%E6%9C%AC%E8%AA%9E', source_url: 'https://www.google.co.jp/?q=日本語')

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://whattosay.net/2018/11/27/【nhk】ネット利用だけでも契約すべきなのか？/')
      assert_equal(@handler.summary[:result].first, rewrited_url: 'https://whattosay.net/2018/11/27/%E3%80%90nhk%E3%80%91%E3%83%8D%E3%83%83%E3%83%88%E5%88%A9%E7%94%A8%E3%81%A0%E3%81%91%E3%81%A7%E3%82%82%E5%A5%91%E7%B4%84%E3%81%99%E3%81%B9%E3%81%8D%E3%81%AA%E3%81%AE%E3%81%8B%EF%BC%9F/', source_url: 'https://whattosay.net/2018/11/27/【nhk】ネット利用だけでも契約すべきなのか？/')
    end
  end
end
