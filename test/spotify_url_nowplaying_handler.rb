module MulukhiyaTootProxy
  class SpotifyURLNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('spotify_url_nowplaying')
    end

    def test_handle_pre_toot
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying https://open.spotify.com/\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS\n"})
      assert_equal(@handler.result[:entries], ['https://open.spotify.com/track/0nfc11o6frUdWKgG51OVFS'])
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
