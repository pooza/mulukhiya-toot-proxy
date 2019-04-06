require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigCommandHandlerTest < Test::Unit::TestCase
    def setup
      config = Config.instance
      @handler = Handler.create('user_config_command')
      @handler.mastodon = Mastodon.new(config['/instance_url'], config['/test/token'])
    end

    def test_exec
      key = SecureRandom.hex(16)

      @handler.exec({'status' => ''})
      assert_equal(@handler.summary, 'UserConfigCommandHandler,0')

      @handler.exec({'status' => "command: user_config\n#{key}: 1"})
      assert_equal(@handler.summary, 'UserConfigCommandHandler,1')

      @handler.exec({'status' => "command: user_config\n#{key}: null"})
      assert_equal(@handler.summary, 'UserConfigCommandHandler,2')

      @handler.exec({'status' => %({"command": "user_config", "#{key}": 2})})
      assert_equal(@handler.summary, 'UserConfigCommandHandler,3')

      @handler.exec({'status' => %({"command": "user_config", "#{key}": null})})
      assert_equal(@handler.summary, 'UserConfigCommandHandler,4')
    end
  end
end
