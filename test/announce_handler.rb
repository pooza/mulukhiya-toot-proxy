module Mulukhiya
  class AnnounceHandlerTest < TestCase
    def setup
      @handler = AnnounceHandler.new
      @handler.payload = {content: "1行目\n\n2行目"}
    end

    def test_create_body
      assert_equal(@handler.create_body, "1行目\n\n2行目\n")
    end
  end
end
