module Mulukhiya
  class HexoAnnounceHandlerTest < TestCase
    def setup
      @handler = Handler.create(:hexo_announce)
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      @handler.handle_announce({content: 'お知らせです。Hexo'}, {sns: info_agent_service})

      assert_path_exist(@handler.debug_info[:result].first[:path])
    end
  end
end
