module MulukhiyaTootProxy
  class ItunesURLHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('itunes_url')
    end

    def test_exec
      @handler.clear
      @handler.exec({'status' => 'https://itunes.apple.com/'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.exec({'status' => 'https://itunes.apple.com/jp/album/%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A25-%E3%83%95%E3%83%AB-%E3%82%B9%E3%83%AD%E3%83%83%E3%83%88%E3%83%AB-go-go/398139262?i=398139273&uo=4'})
      assert_equal(@handler.result[:entries], ['https://itunes.apple.com/jp/album/%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A25-%E3%83%95%E3%83%AB-%E3%82%B9%E3%83%AD%E3%83%83%E3%83%88%E3%83%AB-go-go/398139262?i=398139273&uo=4'])
    end
  end
end
