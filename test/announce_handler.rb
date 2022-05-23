module Mulukhiya
  class AnnounceHandlerTest < TestCase
    def toggleable?
      return false unless controller_class.announcement?
      return super
    end

    def setup
      @handler = AnnounceHandler.new
      @handler.payload = {content: "1行目\n\n2行目"}
    end

    def test_create_body
      assert_equal("1行目\n\n2行目\n", @handler.create_body)
    end
  end
end
