module Mulukhiya
  class YouTubeImageHandlerTest < TestCase
    def setup
      @handler = Handler.create('you_tube_image')
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.youtube.com/')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://music.youtube.com/watch?v=HjsKI-StQPU&list=RDAMVMmwJiuNq1eHY')
      assert(@handler.debug_info[:result].present?) if @handler.debug_info
    end
  end
end
