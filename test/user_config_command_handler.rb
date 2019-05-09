require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < Test::Unit::TestCase
    def setup
      @handler = Handler.create('user_config_command')
      @key = SecureRandom.hex(16)
    end

    def test_exec
      @handler.clear
      @handler.exec({'status' => ''})
      assert_nil(@handler.result)

      @handler.clear
      @handler.exec({'status' => "command: user_config\n#{@key}: 1"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.exec({'status' => "command: user_config\n#{@key}: null"})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.exec({'status' => %({"command": "user_config", "#{@key}": 2})})
      assert(@handler.result[:entries].present?)

      @handler.clear
      @handler.exec({'status' => %({"command": "user_config", "#{@key}": null})})
      assert(@handler.result[:entries].present?)
    end
  end
end
