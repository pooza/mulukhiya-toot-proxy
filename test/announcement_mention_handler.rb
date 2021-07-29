module Mulukhiya
  class AnnouncementHandlerTest < TestCase
    def setup
      @handler = Handler.create('announcement_mention')
    end

    def test_template
      assert_kind_of(Template, @handler.template)
    end

    def test_respondable?
      @handler.handle_mention('status' => {'content' => 'プリキュアパレス'})
      assert_false(@handler.respondable?)

      @handler.handle_mention('status' => {'content' => 'お知らせ'})
      assert(@handler.respondable?)
    end
  end
end
