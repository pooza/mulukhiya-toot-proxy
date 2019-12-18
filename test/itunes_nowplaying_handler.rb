module MulukhiyaTootProxy
  class ItunesNowplayingHandlerTest < TestCase
    def setup
      @handler = Handler.create('itunes_nowplaying')
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot({message_field => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(@handler.result[:entries], ['#五條真由美 ガンバランス de ダンス'])
    end
  end
end
