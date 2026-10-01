module Mulukhiya
  class SidekiqDaemonTest < TestCase
    # monit が /health の失敗から restart を撃つまでの窓（秒）(#4697)。
    #
    # ⚠ **値の出所はモロヘイヤの外にある**ので、ここでは定数として持つしかない。
    # - `set daemon 30` … pooza/chubo-core の `cookbooks/monit/templates/monitrc.erb`
    # - `for 3 cycles` … pooza/chubo2 の `app/cookbooks/mulukhiya/templates/monit.erb`
    # どちらかを動かしたら、ここも合わせること。
    MONIT_POLL_SECONDS = 30
    MONIT_FAILURE_CYCLES = 3
    MONIT_RESTART_WINDOW = MONIT_POLL_SECONDS * MONIT_FAILURE_CYCLES

    # monit の restart が stop を鎖で呼ぶ順（monit.erb の `services`）。
    RCD_SERVICES = ['mulukhiya-puma', 'mulukhiya-sidekiq', 'mulukhiya-listener'].freeze

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

    # ⚠⚠ **上限側も見る (#4697)。**monit は `service ... restart` を 3 本の鎖で撃つので、
    # 停止待ちの最悪（`kill_wait` ＋ SIGKILL 後の `sleep`）の合計が monit の窓を超えると、
    # 1 本目の restart の最中に次の restart が撃たれる（sidekiq 二重起動と同型）。
    # 下限（`SHUTDOWN_TIMEOUT` より長いこと）だけを守って `kill_wait` を上げると、
    # こちら側が黙って破れる。
    def test_rcd_stop_chain_fits_in_the_monit_window
      total = RCD_SERVICES.sum {|service| rcd_worst_stop_seconds(service)}

      assert_operator(
        total, :<, MONIT_RESTART_WINDOW,
        "rc.d の停止待ちの合計 #{total} 秒が monit の窓 #{MONIT_RESTART_WINDOW} 秒を超える"
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

    def rcd_kill_wait(service = 'mulukhiya-sidekiq')
      path = rcd_path(service)
      key = "#{service.tr('-', '_')}_kill_wait"
      matched = File.read(path)[/^#{key}=(\d+)$/, 1]
      raise "#{key} not found in #{path}" unless matched
      return matched.to_i
    end

    # 停止待ちの最悪。待ちループを走り切り、SIGKILL の後の `sleep` まで待つ場合。
    def rcd_worst_stop_seconds(service)
      path = rcd_path(service)
      matched = File.read(path)[/^\s*pkill -9 .*\n\s*sleep (\d+)$/, 1]
      raise "sleep after SIGKILL not found in #{path}" unless matched
      return rcd_kill_wait(service) + matched.to_i
    end

    def rcd_path(service)
      return File.join(Environment.dir, 'config/sample/freebsd', service)
    end
  end
end
