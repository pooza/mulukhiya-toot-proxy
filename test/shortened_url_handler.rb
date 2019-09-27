module MulukhiyaTootProxy
  class ShortenedURLHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('shortened_url')
    end

    def test_handle_pre_toot
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://www.google.co.jp/?q=日本語'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://4sq.com/2NYeZb6'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'キュアスタ！ https://goo.gl/uJJKpV'})
      assert_equal(@handler.result[:entries].count, 1)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://bit.ly/2Lquwnt'})
      assert_equal(@handler.result[:entries].count, 1)

      @handler.clear
      @handler.handle_pre_toot({'status' => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW'})
      assert_equal(@handler.result[:entries].count, 2)
    end
  end
end
