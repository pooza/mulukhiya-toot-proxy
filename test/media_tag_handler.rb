module Mulukhiya
  class MediaTagHandlerTest < TestCase
    def setup
      @handler = Handler.create('media_tag')
    end

    def test_all
      assert_kind_of(Hash, @handler.all)
      assert(@handler.all[:image].present?)
      assert(@handler.all[:video].present?)
      assert(@handler.all[:audio].present?)
    end
  end
end
