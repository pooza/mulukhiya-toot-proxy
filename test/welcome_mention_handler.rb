module Mulukhiya
  class WelcomeMentionHandlerTest < TestCase
    def setup
      @handler = Handler.create('welcome_mention')
    end

    def test_template
      assert_kind_of(Template, @handler.template)
    end

    def test_respondable?
      @handler.handle_mention('status' => {'content' => 'プリキュアパレス'})
      assert_predicate(@handler, :respondable?)

      @handler.handle_mention('status' => {'content' => 'お知らせ'})
      assert_predicate(@handler, :respondable?)
    end
  end
end
