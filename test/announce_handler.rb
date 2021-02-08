module Mulukhiya
  class AnnounceHandlerTest < TestCase
    def setup
      @handler = AnnounceHandler.new
      @announcement = {text: "1行目\n\n2行目"}
    end

    def test_create_body
      assert_equal(@handler.create_body(@announcement), "1行目\n\n2行目\n")
    end
  end
end
