module Mulukhiya
  class TweetHandlerTest < TestCase
    def setup
      @handler = Handler.create('tweet')
    end

    def test_disable?
      assert_false(@handler.disable?)
    end

    def test_handle_toot?
      @handler.clear
      @handler.handle_toot({status_field => 'hoge', 'visibility' => 'private'})
      assert_equal(@handler.result.count, 1)

      @handler.clear
      @handler.handle_toot({status_field => '@pooza hello'})
      assert_equal(@handler.result.count, 1)

      @handler.clear
      @handler.handle_toot({status_field => "command: user_config\n"})
      assert_equal(@handler.result.count, 1)

      @handler.clear
      @handler.handle_toot({status_field => 'hoge', 'visibility' => 'public'})
      assert_equal(@handler.result.count, 2)

      @handler.clear
      @handler.handle_toot({status_field => 'fuga'})
      assert_equal(@handler.result.count, 2)
    end
  end
end
