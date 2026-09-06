module Mulukhiya
  class SudekiqDaemonTest < TestCase
    def setup
      @daemon = SidekiqDaemon.new
      config['/crypt/password'] = 'mulukhiya'
      config['/crypt/encoder'] = 'base64'
      config['/sidekiq/auth/user'] = 'admin'
      config['/sidekiq/auth/password'] = 'o/ubs+gIuqRoJD9rCAM8XA==::::YtaCwlriV4w=' # 'aaa'
    end

    def test_auth?
      assert_false(SidekiqDaemon.auth?('', ''))
      assert_false(SidekiqDaemon.auth?('admin', ''))
      assert_false(SidekiqDaemon.auth?('', 'aaa'))
      assert_false(SidekiqDaemon.auth?('admi', 'aaa'))
      assert(SidekiqDaemon.auth?('admin', 'aaa'))
    end

    def test_command
      assert_kind_of(CommandLine, @daemon.command)
    end

    def test_disable?
      assert_false(SidekiqDaemon.disable?)
    end

    # ⚠⚠ **rc.d の SIGKILL は Sidekiq の停止の締切より後に撃つ (#4675 の Codex P1)。**
    # 先に撃つと hard shutdown（積み残しをキューへ戻す経路）へ到達できず、
    # ⚠ ワーカーの 15 本中 14 本が `retry: false` なので**その仕事は消える**。
    #
    # ⚠ 「シェルスクリプトだから検査できない」で放置すると、片方だけ動かした時に
    # 誰も気づけない。値を直接読んで突き合わせる。
    def test_rcd_waits_past_the_shutdown_deadline
      assert_operator(
        rcd_kill_wait, :>, SidekiqDaemon::SHUTDOWN_TIMEOUT,
        'rc.d の SIGKILL が Sidekiq の hard shutdown より先に撃たれる'
      )
    end

    # 締切そのものを上流の既定に委ねない。委ねると Sidekiq のバージョン更新で
    # rc.d 側と黙って食い違う。
    def test_shutdown_timeout_is_explicit
      assert_kind_of(Integer, SidekiqDaemon::SHUTDOWN_TIMEOUT)
      assert_operator(SidekiqDaemon::SHUTDOWN_TIMEOUT, :>, 0)
    end

    private

    def rcd_kill_wait
      path = File.join(Environment.dir, 'config/sample/freebsd/mulukhiya-sidekiq')
      matched = File.read(path)[/^mulukhiya_sidekiq_kill_wait=(\d+)$/, 1]
      raise "mulukhiya_sidekiq_kill_wait not found in #{path}" unless matched
      return matched.to_i
    end
  end
end
