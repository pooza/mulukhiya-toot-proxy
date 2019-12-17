module MulukhiyaTootProxy
  class CanonicalURLHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('canonical_url')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://www.google.co.jp/?q=日本語'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://4sq.com/2NYeZb6'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://www.youtube.com/watch?v=Lvinns9DJs0&feature=youtu.be&t=2252'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'http://www.apple.com'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'http://www.apple.com/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://stats.uptimerobot.com/QOoGgF2Ak'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://www.apple.com/jp/apple-music/'})
      assert_equal(@handler.result[:entries].first[:rewrited_url], 'https://www.apple.com/jp/apple-music/')
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
