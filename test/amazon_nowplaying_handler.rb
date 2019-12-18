module MulukhiyaTootProxy
  class AmazonNowplayingHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('amazon_nowplaying')
    end

    def test_handle_pre_toot
      return if @handler.nil? || @handler.disable?
      @handler.clear
      @handler.handle_pre_toot({message_field => "#nowplaying #五條真由美 ガンバランス de ダンス\n"})
      assert(@handler.result[:entries].present?)
    end

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
