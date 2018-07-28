require 'mulukhiya/handler/canonical'

module MulukhiyaTootProxy
  class CanonicalHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = CanonicalHandler.new
      assert_equal(handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})['status'], 'https://www.google.co.jp/?q=日本語')
      assert_equal(handler.result, 'CanonicalHandler,0')

      assert_equal(handler.exec({'status' => 'http://junzou-marketing.com/seo-canonical'})['status'], 'https://junzou-marketing.com/seo-canonical')
      assert_equal(handler.result, 'CanonicalHandler,1')
    end
  end
end
