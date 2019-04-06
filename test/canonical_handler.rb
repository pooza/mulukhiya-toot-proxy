module MulukhiyaTootProxy
  class CanonicalHandlerTest < Test::Unit::TestCase
    def test_exec
      handler = Handler.create('canonical')
      assert_equal(handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})['status'], 'https://www.google.co.jp/?q=日本語')
      assert_equal(handler.summary, 'CanonicalHandler,0')

      assert_equal(handler.exec({'status' => 'http://mstdn.b-shock.org/about'})['status'], 'https://mstdn.b-shock.org/about')
      assert_equal(handler.summary, 'CanonicalHandler,1')

      assert_equal(handler.exec({'status' => 'https://4sq.com/2NYeZb6'})['status'], 'https://4sq.com/2NYeZb6')
      assert_equal(handler.summary, 'CanonicalHandler,1')

      assert_equal(handler.exec({'status' => 'https://www.youtube.com/watch?v=Lvinns9DJs0&feature=youtu.be&t=2252'})['status'], 'https://www.youtube.com/watch?v=Lvinns9DJs0&feature=youtu.be&t=2252')
      assert_equal(handler.summary, 'CanonicalHandler,1')
    end
  end
end
