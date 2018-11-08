module MulukhiyaTootProxy
  class ShortenedUrlHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('shortened_url')
      assert_equal(handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})['status'], 'https://www.google.co.jp/?q=日本語')
      assert_equal(handler.result, 'ShortenedUrlHandler,0')

      assert_equal(handler.exec({'status' => 'キュアスタ！ https://goo.gl/uJJKpV'})['status'], 'キュアスタ！ https://precure.ml/')
      assert_equal(handler.result, 'ShortenedUrlHandler,1')

      assert_equal(handler.exec({'status' => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW'})['status'], 'https://precure.ml/ https://mstdn.b-shock.org/')
      assert_equal(handler.result, 'ShortenedUrlHandler,3')

      assert_equal(handler.exec({'status' => 'https://bit.ly/2Lquwnt'})['status'], 'https://www.amazon.co.jp/HUG%E3%81%A3%E3%81%A8-%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2-%E3%82%AD%E3%83%A5%E3%83%BC%E3%83%86%E3%82%A3%E3%83%BC%E3%83%95%E3%82%A3%E3%82%AE%E3%83%A5%E3%82%A23-SpecialSet-1%E3%82%BB%E3%83%83%E3%83%88%E5%85%A5%E3%82%8A/dp/B07CJ4KH1T/ref=pd_lutyp_cxhsh_1_4?_encoding=UTF8&pd_rd_i=B07CJ4KH1T&pd_rd_r=5192aa37-9e12-4c94-9aa0-27ddc08af25e&pd_rd_w=WUAm6&pd_rd_wg=cinNf&psc=1&refRID=WZPP1MGCVXZR7KEAQYB8')
      assert_equal(handler.result, 'ShortenedUrlHandler,4')

      assert_equal(handler.exec({'status' => 'https://4sq.com/2NYeZb6'})['status'], 'https://4sq.com/2NYeZb6')
      assert_equal(handler.result, 'ShortenedUrlHandler,4')
    end
  end
end
