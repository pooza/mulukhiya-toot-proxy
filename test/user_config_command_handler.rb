require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_status
      return if invalid_handler?
      assert(YAML.safe_load(@handler.status).is_a?(Hash))
    end

    def test_handle_pre_toot
      return if invalid_handler?

      @handler.clear
      @handler.handle_pre_toot({message_field => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({message_field => "command: user_config\n#{@key}: 1"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({message_field => "command: user_config\n#{@key}: null"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({message_field => %({"command": "user_config", "#{@key}": 2})})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({message_field => %({"command": "user_config", "#{@key}": null})})
      assert(@handler.result[:entries].present?)
    end
  end
end
