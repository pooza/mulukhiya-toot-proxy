module MulukhiyaTootProxy
  class MentionVisibilityHandlerTest < TestCase
    def setup
      @handler = Handler.create('mention_visibility')
      @config = Config.instance
      @config['/agent/accts'] = ['@relayctl@hashtag-relay.dtp-mstdn.jp']
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_post_toot({status_field => 'ふつうのトゥート。'})
      assert_nil(@handler.result)

      @handler.clear
      r = @handler.handle_pre_toot({status_field => '@relayctl@hashtag-relay.dtp-mstdn.jp subscribe #mulukhiya'})
      assert_equal(@handler.result[:entries], ['@relayctl@hashtag-relay.dtp-mstdn.jp'])
      assert_equal(r['visibility'], Environment.controller_class.visibility_name('direct'))
    end
  end
end
