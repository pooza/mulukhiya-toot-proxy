require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_status
      return unless handler?
      assert_kind_of(Hash, YAML.safe_load(@handler.status))
    end

    def test_handle_pre_toot
      return unless handler?

      @handler.clear
      @handler.handle_pre_toot({status_field => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({status_field => "command: user_config\n#{@key}: 1"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({status_field => "command: user_config\n#{@key}: null"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({status_field => %({"command": "user_config", "#{@key}": 2})})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({status_field => %({"command": "user_config", "#{@key}": null})})
      assert(@handler.result[:entries].present?)
    end
  end
end
