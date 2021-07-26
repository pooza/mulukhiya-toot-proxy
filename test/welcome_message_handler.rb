module Mulukhiya
  class WelcomeMessageHandlerTest < TestCase
    def setup
      @handler = Handler.create('welcome_message')
    end

    def test_template
      assert_kind_of(Template, @handler.template)
    end
  end
end
