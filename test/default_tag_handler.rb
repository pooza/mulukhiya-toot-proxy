module Mulukhiya
  class DefaultTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:default_tag)
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => "つよく、やさしく、美しく。\n#キュアマーメイド")

      assert_predicate(@handler.addition_tags.count, :positive?)
    end
  end
end
