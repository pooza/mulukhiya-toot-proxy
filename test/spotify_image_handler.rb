module MulukhiyaTootProxy
  class SpotifyImageHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('spotify_image')
    end

    def test_handle_pre_toot
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://www.spotify.com/jp/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://open.spotify.com/track/1nRvy34z0NcTga59qOSYId'})
      assert(@handler.result[:entries].present?) if @handler.result
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
