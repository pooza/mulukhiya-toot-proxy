module Mulukhiya
  class MediaTagHandlerTest < TestCase
    def setup
      @handler = Handler.create('media_tag')
    end

    def test_all
      assert_kind_of(Hash, @handler.class.all)
      assert(@handler.class.all[:image].present?)
      assert(@handler.class.all[:video].present?)
      assert(@handler.class.all[:audio].present?)
    end
  end
end
