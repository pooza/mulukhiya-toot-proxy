module Mulukhiya
  class SpoilerHandlerTest < TestCase
    def setup
      @handler = Handler.create('spoiler')
    end

    def test_handle_pre_toot
      @handler.clear
      body = {
        controller_class.status_field => '普通の文章',
      }
      @handler.handle_pre_toot(body)
      assert_nil(@handler.debug_info)

      @handler.clear
      body = {
        controller_class.status_field => '普通の文章',
        controller_class.status_field => '18禁',
      }
      @handler.handle_pre_toot(body)
      assert_nil(@handler.debug_info)
      assert_equal(body[controller_class.status_field], '18禁')

      @handler.clear
      body = {
        controller_class.spoiler_field => 'ネタバレ',
        controller_class.status_field => 'ネタバレ文章',
      }
      @handler.handle_pre_toot(body)
      assert_not_equal(body[controller_class.spoiler_field], 'ネタバレ')
      assert(body[controller_class.spoiler_field].end_with?('ネタバレ'))
    end
  end
end
