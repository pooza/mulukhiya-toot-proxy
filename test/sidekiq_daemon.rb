module Mulukhiya
  class SudekiqDaemonTest < TestCase
    def setup
      @daemon = SidekiqDaemon.new
      config['/crypt/password'] = 'mulukhiya'
      config['/crypt/encoder'] = 'base64'
      config['/sidekiq/auth/user'] = 'admin'
      config['/sidekiq/auth/password'] = 'o/ubs+gIuqRoJD9rCAM8XA==::::YtaCwlriV4w=' # 'aaa'
    end

    def test_auth
      assert_false(SidekiqDaemon.auth('', ''))
      assert_false(SidekiqDaemon.auth('admin', ''))
      assert_false(SidekiqDaemon.auth('', 'aaa'))
      assert_false(SidekiqDaemon.auth('admi', 'aaa'))
      assert(SidekiqDaemon.auth('admin', 'aaa'))
    end

    def test_command
      assert_kind_of(CommandLine, @daemon.command)
    end

    def test_motd
      assert_kind_of(String, @daemon.motd)
    end
  end
end
