require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('user_config_command')
    end

    def test_exec
      key = SecureRandom.hex(16)

      @handler.exec({'status' => ''})
      assert_nil(@handler.result)

      @handler.exec({'status' => "command: user_config\n#{key}: 1"})
      assert_equal(@handler.result[:entries].count, 1)

      @handler.exec({'status' => "command: user_config\n#{key}: null"})
      assert_equal(@handler.result[:entries].count, 2)

      @handler.exec({'status' => %({"command": "user_config", "#{key}": 2})})
      assert_equal(@handler.result[:entries].count, 3)

      @handler.exec({'status' => %({"command": "user_config", "#{key}": null})})
      assert_equal(@handler.result[:entries].count, 4)
    end
  end
end
