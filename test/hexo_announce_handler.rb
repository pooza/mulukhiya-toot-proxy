module Mulukhiya
  class HexoAnnounceHandlerTest < TestCase
    def setup
      @handler = Handler.create('hexo_announce')
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      return unless handler?

      @handler.clear
      @handler.handle_announce({text: 'お知らせです。Hexo'}, {sns: info_agent_service})
      assert(File.exist?(@handler.debug_info[:result].first[:path]))
    end
  end
end
