require 'mulukhiya-toot-proxy/handler/amazon_asin'

module MulukhiyaTootProxy
  class ShortenedUrlHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = ShortenedUrlHandler.new
      assert_equal(handler.exec({'status' => 'キュアスタ！ https://goo.gl/uJJKpV'})['status'], 'キュアスタ！ https://precure.ml/')
      assert_equal(handler.result, 'ShortenedUrlHandler,1')

      assert_equal(handler.exec({'status' => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW'})['status'], 'https://precure.ml/ https://mstdn.b-shock.org/')
      assert_equal(handler.result, 'ShortenedUrlHandler,3')
    end
  end
end
