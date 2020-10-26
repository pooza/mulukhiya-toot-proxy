module Mulukhiya
  class GoodMorningHandlerTest < TestCase
    def setup
      @handler = Handler.create('good_morning')
    end

    def test_handle_post_toot
      return unless handler?

      @handler.clear
      @handler.handle_post_toot(status_field => 'うどん')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_post_toot(status_field => '@makoto おはようございます。')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_post_toot(status_field => 'おはようございます。いい天気ですね。')
      assert_equal(@handler.debug_info[:result].first, {program: {updated: true}})
    end
  end
end
