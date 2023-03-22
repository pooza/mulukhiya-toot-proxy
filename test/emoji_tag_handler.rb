module Mulukhiya
  class EmojiTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:emoji_tag)
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => '')

      assert_false(@handler.addition_tags.count.positive?)

      @handler.handle_pre_toot(status_field => ":netabare:")

      assert_predicate(@handler.addition_tags.count, :positive?)
    end
  end
end
