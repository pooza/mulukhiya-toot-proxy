module Mulukhiya
  class GrowiAnnouncementHandlerTest < TestCase
    def setup
      @handler = Handler.create('growi_announcement')
      config['/agent/info/token'] = config['/agent/test/token']
    end

    def test_handle_announce
      return unless handler?

      @handler.clear
      @handler.handle_announce({text: 'お知らせです。GROWI'}, {sns: info_agent_service})
      assert_kind_of(String, @handler.debug_info[:result].first[:path])
    end
  end
end
