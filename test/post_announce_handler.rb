module Mulukhiya
  class PostAnnounceHandlerTest < TestCase
    def setup
      @handler = Handler.create('post_announce')
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      return unless handler?

      @handler.clear
      @handler.handle_announce({text: 'お知らせです。'}, {sns: info_agent_service})
      assert_kind_of(Array, @handler.debug_info[:result])
    end
  end
end
