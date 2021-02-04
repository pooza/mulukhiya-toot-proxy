module Mulukhiya
  class DropboxAnnounceHandlerTest < TestCase
    def setup
      @handler = Handler.create('dropbox_announce')
      config['/agent/info/token'] = test_token
    end

    def test_handle_announce
      return unless handler?

      @handler.clear
      @handler.handle_announce({text: 'お知らせです。Dropbox'}, {sns: info_agent_service})
      assert_kind_of(String, @handler.debug_info[:result].first[:path])
    end
  end
end
