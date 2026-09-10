module Mulukhiya
  class SidekiqDaemonTest < TestCase
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

    # ⚠⚠ **initializer のブロックは sidekiq の CLI でしか実行されない (#4687)。**
    # `Sidekiq.configure_server` は `Sidekiq.server?` が false の環境では yield しない
    # ので、あそこに書いた行は `rake test` でも fedi-test-harness でも puma からも
    # 1 行も走らない。🔴 **`Sidekiq::Config#timeout=` は存在しないのに CI 緑・harness
    # 両系緑のまま本番の起動で初めて発火した**のがそれ。
    #
    # ⚠ **実物の `Sidekiq::Config` を渡す。**ダブルを渡すと「存在しない setter を
    # 呼んでいる」というこの欠陥そのものを取り逃がす。
    def test_configure_server
      sidekiq = Sidekiq::Config.new
      assert_nothing_raised do
        SidekiqDaemon.configure_server(sidekiq, sidekiq_config)
      end
      assert_equal(SidekiqDaemon::SHUTDOWN_TIMEOUT, sidekiq[:timeout])
      assert_equal(3, sidekiq.concurrency)
      assert_equal(['media_catalog'], sidekiq.capsule(:media_catalog).queues)
      assert_equal(2, sidekiq.capsule(:media_catalog).concurrency)
    end

    # ⚠ **`timeout` に setter は無い** (#4687)。`concurrency` にはあるので
    # 「片方あるなら両方あるだろう」で書くと落ちる。上流が setter を生やしたら
    # このテストは落ちてよい（そのときは initializer 側も見直す合図）。
    def test_sidekiq_config_has_no_timeout_writer
      assert_false(Sidekiq::Config.new.respond_to?(:timeout=))
      assert_respond_to(Sidekiq::Config.new, :concurrency=)
    end

    # capsule の設定が無くても media_catalog キューを listen する capsule は立てる。
    def test_configure_server_without_capsule_config
      sidekiq = Sidekiq::Config.new
      SidekiqDaemon.configure_server(sidekiq, sidekiq_config.merge(capsule: nil))

      assert_equal(['media_catalog'], sidekiq.capsule(:media_catalog).queues)
      assert_equal(1, sidekiq.capsule(:media_catalog).concurrency)
    end

    private

    def sidekiq_config
      return {
        redis: {dsn: 'redis://127.0.0.1:6379/2'},
        concurrency: 3,
        logger: {level: 1},
        capsule: {media_catalog: {concurrency: 2}},
      }
    end

    def rcd_kill_wait
      path = File.join(Environment.dir, 'config/sample/freebsd/mulukhiya-sidekiq')
      matched = File.read(path)[/^mulukhiya_sidekiq_kill_wait=(\d+)$/, 1]
      raise "mulukhiya_sidekiq_kill_wait not found in #{path}" unless matched
      return matched.to_i
    end
  end
end
