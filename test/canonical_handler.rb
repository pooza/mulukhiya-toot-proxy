module MulukhiyaTootProxy
  class CanonicalHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('canonical')
    end

    def test_hook_pre_toot
      @handler.clear
      @handler.hook_pre_toot({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => 'https://4sq.com/2NYeZb6'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => 'https://www.youtube.com/watch?v=Lvinns9DJs0&feature=youtu.be&t=2252'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => 'http://www.apple.com'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => 'http://www.apple.com/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.hook_pre_toot({'status' => 'https://www.apple.com/jp/apple-music/'})
      assert_equal(@handler.result[:entries], ['https://www.apple.com/jp/apple-music/'])
    end
  end
end
