module Mulukhiya
  class WelcomeMessageFollowHandlerTest < TestCase
    def setup
      @handler = Handler.create('welcome_message_follow')
    end

    def test_template
      assert_kind_of(Template, @handler.template)
    end
  end
end
