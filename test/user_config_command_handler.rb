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
      assert_nil(@handler.summary)

      @handler.clear
      @handler.handle_toot(status_field => "command: user_config\n#{@key}: 1")
      assert(@handler.summary[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => "command: user_config\n#{@key}: null")
      assert(@handler.summary[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => %({"command": "user_config", "#{@key}": 2}))
      assert(@handler.summary[:result].present?)

      @handler.clear
      @handler.handle_toot(status_field => %({"command": "user_config", "#{@key}": null}))
      assert(@handler.summary[:result].present?)
    end
  end
end
