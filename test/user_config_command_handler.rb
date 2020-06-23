require 'securerandom'

module Mulukhiya
  class UserConfigCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_handle_toot
      return unless handler?

      @handler.clear
      @handler.handle_toot(status_field => '')
      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_toot(status_field => "command: user_config\n#{@key}: 1")
      assert(@handler.debug_info[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: user_config\n#{@key}: null")
      assert(@handler.debug_info[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => %({"command": "user_config", "#{@key}": 2}))
      assert(@handler.debug_info[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => %({"command": "user_config", "#{@key}": null}))
      assert(@handler.debug_info[:result].present?)
    end
  end
end
