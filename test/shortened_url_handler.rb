module Mulukhiya
  class ShortenedURLHandlerTest < TestCase
    def setup
      @handler = Handler.create('shortened_url')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp/?q=日本語')
      assert_nil(@handler.summary)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://4sq.com/2NYeZb6')
      assert_nil(@handler.summary)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'キュアスタ！ https://goo.gl/uJJKpV')
      assert_equal(@handler.summary[:result].count, 1)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://bit.ly/2Lquwnt')
      assert_equal(@handler.summary[:result].count, 1)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW')
      assert_equal(@handler.summary[:result].count, 2)
    end
  end
end
