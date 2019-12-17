module MulukhiyaTootProxy
  class YouTubeURLNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('you_tube_url_nowplaying')
    end

    def test_handle_pre_toot
      return if @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying https://www.youtube.com\n"})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying https://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.result[:entries], ['https://www.youtube.com/watch?v=uFfsTeExwbQ'])

      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying \n\nhttps://www.youtube.com/watch?v=uFfsTeExwbQ\n"})
      assert_equal(@handler.result[:entries], ['https://www.youtube.com/watch?v=uFfsTeExwbQ'])
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
