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
      assert(@handler.result.count.zero?)

      @handler.clear
      @handler.handle_toot({status_field => '@pooza hello', 'visibility' => 'public'})
      assert(@handler.result.count.positive?)

      @handler.clear
      @handler.handle_toot({status_field => "command: user_config\n", 'visibility' => 'public'})
      assert(@handler.result.count.positive?)

      @handler.clear
      @handler.handle_toot({status_field => 'hoge', 'visibility' => 'public'})
      assert(@handler.result.count.positive?)
    end
  end
end
