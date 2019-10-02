module MulukhiyaTootProxy
  class ItunesNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('itunes_nowplaying')
    end

    def test_handle_pre_toot
      return if Environment.ci?
      return if @handler.disable?

      @handler.handle_pre_toot({'status' => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert_equal(@handler.result[:entries], ['#五條真由美 ガンバランス de ダンス'])
    end
  end
end
