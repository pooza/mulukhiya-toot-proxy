module Mulukhiya
  class DefaultTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:default_tag)
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => "つよく、やさしく、美しく。\n#キュアマーメイド")

      assert_predicate(@handler.addition_tags.count, :positive?)
    end

    def test_skips_when_channel_post
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        :channelId => 'channel-123',
      )

      assert_false(@handler.executable?)
    end

    def test_skips_when_channel_post_string_key
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        'channelId' => 'channel-123',
      )

      assert_false(@handler.executable?)
    end

    def test_skips_when_local_only
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        'localOnly' => true,
      )

      assert_false(@handler.executable?)
    end

    def test_skips_when_local_only_symbol_key
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        :localOnly => true,
      )

      assert_false(@handler.executable?)
    end

    def test_skips_when_local_only_string_value
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        'localOnly' => 'true',
      )

      assert_false(@handler.executable?)
    end

    def test_skips_when_channel_post_empty_value
      @handler.handle_pre_toot(
        status_field => "つよく、やさしく、美しく。\n#キュアマーメイド",
        'channelId' => '',
      )

      assert_false(@handler.executable?)
    end
  end
end
