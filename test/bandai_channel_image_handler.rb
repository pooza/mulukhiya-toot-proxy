module Mulukhiya
  class BandaiChannelImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('bandai_channel_image')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.b-ch.com/')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.b-ch.com/titles/6357/039')
      assert(@handler.debug_info[:result].present?) if @handler.debug_info
    end
  end
end
