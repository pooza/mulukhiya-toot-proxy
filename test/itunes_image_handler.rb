module MulukhiyaTootProxy
  class ItunesImageHandlerTest < Test::Unit::TestCase
    def setup
      @config = Config.instance
      @handler = Handler.create('itunes_image')
      @handler.mastodon = Mastodon.new(@config['/instance_url'], @config['/test/token'])
    end

    def test_exec
      @handler.exec({'status' => 'https://itunes.apple.com/lookup?id=1241907142&lang=ja_jp'})
      assert_nil(@handler.result)

      @handler.exec({'status' => 'https://itunes.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4'})
      assert_equal(@handler.result[:entries].count, 1)
    end
  end
end
