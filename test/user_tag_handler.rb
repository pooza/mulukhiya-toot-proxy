module Mulukhiya
  class UserTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:user_tag)
    end

    def test_handle_pre_toot
      test_account.user_config.update(tagging: {user_tags: ['実況']})
      assert_equal(Set['実況'], @handler.addition_tags)
      test_account.user_config.update(tagging: {user_tags: nil})
    end
  end
end
