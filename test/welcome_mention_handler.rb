module Mulukhiya
  class WelcomeMentionHandlerTest < TestCase
    def setup
      @handler = Handler.create('welcome_mention')
    end

    def test_template
      assert_kind_of(Template, @handler.template)
    end
  end
end
