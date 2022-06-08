module Mulukhiya
  class UserTagHandlerTest < TestCase
    def setup
      @config_handler = Handler.create(:user_config_command)
      @handler = Handler.create(:user_tag)
    end

    def test_handle_pre_toot
      @config_handler.handle_pre_toot(status_field => "command: user_config\ntagging:\n  user_tag: null\n")
      @config_handler.handle_pre_toot(status_field => "command: user_config\ntagging:\n  user_tag:\n  - 実況")
      sleep(1)
      @handler.handle_pre_toot(status_field => "つよく、やさしく、美しく。\n#キュアマーメイド")
      assert_equal(Set['実況'], @handler.addition_tags)
      @config_handler.handle_pre_toot(status_field => "command: user_config\ntagging:\n  user_tag: null\n")
    end
  end
end
