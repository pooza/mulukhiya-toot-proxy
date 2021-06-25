module Mulukhiya
  class MentionVisibilityHandlerTest < TestCase
    def setup
      @handler = Handler.create('mention_visibility')
      config['/agent/accts'] = ['@relayctl@hashtag-relay.dtp-mstdn.jp']
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_post_toot(status_field => 'ふつうのトゥート。')
      assert_nil(@handler.debug_info)

      @handler.clear
      r = @handler.handle_pre_toot(status_field => '@relayctl@hashtag-relay.dtp-mstdn.jp subscribe #mulukhiya')
      assert_equal(@handler.debug_info[:result], [{acct: '@relayctl@hashtag-relay.dtp-mstdn.jp'}])
      assert_equal(r['visibility'], controller_class.visibility_name('direct'))
    end
  end
end
