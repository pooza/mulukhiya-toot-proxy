module MulukhiyaTootProxy
  class ItunesImageHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('itunes_image')
    end

    def test_handle_pre_toot
      return if @handler.nil? || @handler.disable?

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://itunes.apple.com/lookup?id=1241907142&lang=ja_jp'})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => 'https://itunes.apple.com/jp/album/%E3%82%B7%E3%83%A5%E3%83%92-%E3%83%88-%E3%82%A5%E3%83%92-%E3%82%B9%E3%82%A4%E3%83%BC%E3%83%84%E3%82%BF%E3%82%A4%E3%83%A0/1299587212?i=1299587213&uo=4'})
      assert(@handler.result[:entries].present?) if @handler.result
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
