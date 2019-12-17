require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_status
      return if @handler.disable?
      assert(YAML.safe_load(@handler.status).is_a?(Hash))
    end

    def test_handle_pre_toot
      return if @handler.disable?

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

    def message_field
      return Environment.sns_class.message_field
    end
  end
end
