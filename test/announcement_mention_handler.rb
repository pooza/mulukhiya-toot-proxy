module Mulukhiya
  class AnnouncementMentionHandlerTest < TestCase
    def setup
      @handler = Handler.create(:announcement_mention)
    end

    def test_template
      template = @handler.template

      assert_kind_of(Template, template)
      assert_respond_to(template, :to_s)
      assert_predicate(template.to_s, :present?)
    end

    def test_respondable?
      @handler.handle_mention('status' => {'content' => 'プリキュアパレス'})

      assert_false(@handler.respondable?)

      @handler.handle_mention('status' => {'content' => 'お知らせ'})

      assert_predicate(@handler, :respondable?)
    end
  end
end
