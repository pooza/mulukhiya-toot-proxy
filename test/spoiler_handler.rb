module Mulukhiya
  class SpoilerHandlerTest < TestCase
    def setup
      @handler = Handler.create('spoiler')
      config['/spoiler/emoji'] = 'netabare'
    end

    def test_handle_pre_toot
      @handler.clear
      body = {controller_class.status_field => '普通の文章'}
      @handler.handle_pre_toot(body)
      assert_nil(@handler.debug_info)
      assert_equal('普通の文章', body[controller_class.status_field])

      @handler.clear
      body = {controller_class.status_field => '18禁'}
      @handler.handle_pre_toot(body)
      assert_nil(@handler.debug_info)
      assert_equal('18禁', body[controller_class.status_field])

      @handler.clear
      body = {
        controller_class.spoiler_field => 'ネタバレ',
        controller_class.status_field => 'command: user_config',
      }
      @handler.handle_pre_toot(body)
      assert_nil(@handler.debug_info)

      @handler.clear
      body = {
        controller_class.spoiler_field => 'ネタバレ',
        controller_class.status_field => 'ネタバレ文章',
      }
      @handler.handle_pre_toot(body)
      assert_equal(':netabare: ネタバレ', body[controller_class.spoiler_field])

      @handler.clear
      body = {
        controller_class.spoiler_field => ':netabare: ネタバレ',
        controller_class.status_field => 'ネタバレ文章',
      }
      @handler.handle_pre_toot(body)
      assert_equal(':netabare: ネタバレ', body[controller_class.spoiler_field])
    end
  end
end
