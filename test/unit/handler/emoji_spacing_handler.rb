module Mulukhiya
  class EmojiSpacingHandlerTest < TestCase
    ZWSP = '​'.freeze

    def setup
      @handler = Handler.create(:emoji_spacing)
    end

    def test_handle_pre_toot_inserts_zwsp_around_shortcode
      payload = {status_field => 'あ:smile:い'}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal("あ#{ZWSP}:smile:#{ZWSP}い", payload[status_field])
    end

    def test_handle_pre_toot_only_inserts_missing_separators
      payload = {status_field => 'あ :smile: い'}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal('あ :smile: い', payload[status_field])
      assert_nil(@handler.debug_info)
    end

    def test_handle_pre_toot_skips_text_without_shortcode
      payload = {status_field => 'シンプルな投稿。'}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal('シンプルな投稿。', payload[status_field])
      assert_nil(@handler.debug_info)
    end

    def test_handle_pre_toot_handles_multiple_shortcodes
      payload = {status_field => '今日は:cake:と:tea:で休憩'}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal("今日は#{ZWSP}:cake:#{ZWSP}と#{ZWSP}:tea:#{ZWSP}で休憩", payload[status_field])
    end

    def test_handle_pre_toot_preserves_zwsp_separators
      payload = {status_field => "あ#{ZWSP}:smile:#{ZWSP}い"}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal("あ#{ZWSP}:smile:#{ZWSP}い", payload[status_field])
      assert_nil(@handler.debug_info)
    end

    def test_handle_pre_toot_handles_boundary
      payload = {status_field => ':smile:'}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_equal(':smile:', payload[status_field])
      assert_nil(@handler.debug_info)
    end

    def test_handle_pre_toot_skips_empty_status
      payload = {status_field => ''}
      @handler.clear
      @handler.handle_pre_toot(payload)

      assert_nil(@handler.debug_info)
    end
  end
end
