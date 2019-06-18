require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_parse
      assert_nil(@handler.parse(''))
      assert_nil(@handler.parse('123'))
      assert_equal(@handler.parse('{"command": user_config}'), {'command' => 'user_config'})
      assert_equal(@handler.parse('command: user_config'), {'command' => 'user_config'})
    end

    def test_create_status
      return if ENV['CI'].present?
      values = YAML.safe_load(@handler.create_status({}))
      assert(values['webhook']['url'].present?)
    end

    def test_handle_pre_toot
      return if ENV['CI'].present?

      @handler.clear
      @handler.handle_pre_toot({'status' => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.handle_pre_toot({'status' => "command: user_config\n#{@key}: 1"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({'status' => "command: user_config\n#{@key}: null"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({'status' => %({"command": "user_config", "#{@key}": 2})})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.handle_pre_toot({'status' => %({"command": "user_config", "#{@key}": null})})
      assert(@handler.result[:entries].present?)
    end
  end
end
