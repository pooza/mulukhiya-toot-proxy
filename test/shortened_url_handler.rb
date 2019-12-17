module MulukhiyaTootProxy
  class ShortenedURLHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('shortened_url')
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://www.google.co.jp/?q=日本語'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://4sq.com/2NYeZb6'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'キュアスタ！ https://goo.gl/uJJKpV'})
      assert_equal(@handler.result[:entries].count, 1)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://bit.ly/2Lquwnt'})
      assert_equal(@handler.result[:entries].count, 1)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://goo.gl/uJJKpV https://bit.ly/2MeJHvW'})
      assert_equal(@handler.result[:entries].count, 2)
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
