module Mulukhiya
  class PoipikuImageHandlerTest < TestCase
    def setup
      @handler = Handler.create(:poipiku_image)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.poipiku.com/')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://poipiku.com/8066049/8819854.html')
      assert_predicate(@handler.debug_info[:result], :present?) if @handler.debug_info
    end
  end
end
