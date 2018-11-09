module MulukhiyaTootProxy
  class CanonicalHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('canonical')
      assert_equal(handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})['status'], 'https://www.google.co.jp/?q=日本語')
      assert_equal(handler.result, 'CanonicalHandler,0')

      assert_equal(handler.exec({'status' => 'http://mstdn.b-shock.org/about'})['status'], 'https://mstdn.b-shock.org/about')
      assert_equal(handler.result, 'CanonicalHandler,1')

      assert_equal(handler.exec({'status' => 'https://4sq.com/2NYeZb6'})['status'], 'https://4sq.com/2NYeZb6')
      assert_equal(handler.result, 'CanonicalHandler,1')
    end
  end
end
