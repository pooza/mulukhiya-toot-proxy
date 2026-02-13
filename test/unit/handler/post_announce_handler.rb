module Mulukhiya
  class PostAnnounceHandlerTest < TestCase
    def setup
      @handler = Handler.create(:post_announce)
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      @handler.handle_announce({content: 'お知らせです。'}, {sns: info_agent_service})
      result = @handler.debug_info[:result]

      assert_kind_of(Array, result)
      assert_predicate(result, :present?)
    end
  end
end
