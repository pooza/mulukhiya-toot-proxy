module MulukhiyaTootProxy
  class CanonicalHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('canonical')
    end

    def test_exec
      @handler.exec({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'https://4sq.com/2NYeZb6'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'https://www.youtube.com/watch?v=Lvinns9DJs0&feature=youtu.be&t=2252'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'http://www.apple.com'})
      assert_equal(@handler.result[:entries], ['http://www.apple.com'])
    end
  end
end
