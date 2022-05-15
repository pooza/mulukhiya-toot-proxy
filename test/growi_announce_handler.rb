module Mulukhiya
  class GrowiAnnounceHandlerTest < TestCase
    def disable?
      return true unless controller_class.growi?
      return true unless (account.growi rescue nil)
      return super
    end

    def setup
      @handler = Handler.create(:growi_announce)
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      @handler.handle_announce({content: 'お知らせです。GROWI'}, {sns: info_agent_service})
      assert_kind_of(String, @handler.debug_info[:result].first[:path])
    end
  end
end
