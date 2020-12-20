module Mulukhiya
  class PostAnnouncementHandlerTest < TestCase
    def setup
      @handler = Handler.create('post_announcement')
      config['/agent/info/token'] = config['/agent/test/token']
    end

    def test_handle_announce
      return unless handler?

      @handler.clear
      @handler.handle_announce({text: 'お知らせです。'}, {sns: Environment.info_agent_service})
      assert_kind_of(Array, @handler.debug_info[:result])
    end
  end
end
