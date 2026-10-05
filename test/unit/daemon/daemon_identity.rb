module Mulukhiya
  # pid ファイルが指すプロセスの身元確認 (#4792)。
  #
  # ⚠ **実プロセスを立てて `ps` を通す。**`process_command` を差し替えると、
  # 「`ps` の引数が FreeBSD / Linux で通るか」「proctitle がどう見えるか」を見ないまま緑になる。
  class DaemonIdentityTest < TestCase
    TAG = File.basename(Environment.dir)
    PUMA_TITLE = "puma 8.0.2 (tcp://0.0.0.0:3008) [#{TAG}]".freeze
    SIDEKIQ_TITLE = "sidekiq 8.1.7 #{TAG} [0 of 5 busy]".freeze
    LISTENER_TITLE = 'bin/listener_daemon.rb start'.freeze
    WAIT_SECONDS = 5

    def setup
      @pids = []
      @files = []
    end

    def teardown
      @pids.each do |pid|
        Process.kill('KILL', pid)
        Process.wait(pid)
      rescue SystemCallError
        nil
      end
      @files.each {|f| FileUtils.rm_f(f)}
    end

    # 🔴 事故の形そのもの: `PumaDaemon.pid` の番号を sidekiq が引いている。
    def test_puma_pid_taken_by_sidekiq
      assert_equal(:dead, PumaDaemon.new.alive_state_of(spawn_titled(SIDEKIQ_TITLE)))
      assert_equal(:dead, SidekiqDaemon.new.alive_state_of(spawn_titled(PUMA_TITLE)))
      assert_equal(:dead, ListenerDaemon.new.alive_state_of(spawn_titled(PUMA_TITLE)))
    end

    def test_unrelated_process
      pid = spawn_process('sleep', '30')

      [PumaDaemon, SidekiqDaemon, ListenerDaemon].each do |daemon_class|
        assert_equal(:dead, daemon_class.new.alive_state_of(pid), daemon_class.to_s)
      end
    end

    # ⚠ **自分のデーモンは従来どおり生きていると答える**（二重起動を拒む側）。
    def test_own_process
      assert_equal(:alive, PumaDaemon.new.alive_state_of(spawn_titled(PUMA_TITLE)))
      assert_equal(:alive, SidekiqDaemon.new.alive_state_of(spawn_titled(SIDEKIQ_TITLE)))
      assert_equal(:alive, ListenerDaemon.new.alive_state_of(spawn_titled(LISTENER_TITLE)))
    end

    # proctitle を書き換える前（`exec` の直後）の姿でも自分と分かること。
    def test_own_process_before_proctitle
      puma = "ruby /usr/local/bin/puma --config #{Environment.dir}/app/initializer/puma.rb"
      sidekiq = "ruby /usr/local/bin/sidekiq --require #{Environment.dir}/app/initializer/sidekiq.rb"

      assert_equal(:alive, PumaDaemon.new.alive_state_of(spawn_titled(puma)))
      assert_equal(:alive, SidekiqDaemon.new.alive_state_of(spawn_titled(sidekiq)))
      assert_equal(:alive, PumaDaemon.new.alive_state_of(spawn_titled('ruby bin/puma_daemon.rb start')))
    end

    # ⚠ `restart` から立った listener は "... restart" のまま居続ける。
    def test_own_process_started_by_restart
      pid = spawn_titled('bin/listener_daemon.rb restart')

      assert_equal(:alive, ListenerDaemon.new.alive_state_of(pid))
    end

    # 🔴 スクリプト名を引数に含むだけのプロセスを自分と見なさない（PR #4802 の Codex P2）。
    def test_process_merely_mentioning_script
      [
        "vim #{Environment.dir}/app/lib/mulukhiya/daemon/puma_daemon.rb",
        'ruby bin/puma_daemon.rb stop',
        'bin/puma_daemon.rb status',
        'tail -f puma_daemon.rb start.log',
      ].each do |title|
        assert_equal(:dead, PumaDaemon.new.alive_state_of(spawn_titled(title)), title)
      end
      assert_equal(:dead, ListenerDaemon.new.alive_state_of(spawn_titled('less listener_daemon.rb')))
      assert_equal(:dead, SidekiqDaemon.new.alive_state_of(spawn_titled('bin/sidekiq_daemon.rb stop')))
    end

    # 🔴 名前が前方一致するだけの別のチェックアウトを自分と見なさない（PR #4802 の Codex P2）。
    def test_other_checkout_with_similar_name
      puma = spawn_titled("puma 8.0.2 (tcp://0.0.0.0:3009) [#{TAG}-old]")
      sidekiq = spawn_titled("sidekiq 8.1.7 #{TAG}-old [0 of 5 busy]")
      launcher = spawn_titled("ruby /usr/local/bin/puma --config #{Environment.dir}-old/app/initializer/puma.rb")

      assert_equal(:dead, PumaDaemon.new.alive_state_of(puma))
      assert_equal(:dead, SidekiqDaemon.new.alive_state_of(sidekiq))
      assert_equal(:dead, PumaDaemon.new.alive_state_of(launcher))
    end

    # ⚠ 同じホストの Mastodon の puma / sidekiq を自分と誤らない。
    def test_mastodon_process
      puma = spawn_titled('puma 6.6.0 (tcp://127.0.0.1:3000) [live]')
      sidekiq = spawn_titled('sidekiq 8.0.9 live [0 of 25 busy]')

      assert_equal(:dead, PumaDaemon.new.alive_state_of(puma))
      assert_equal(:dead, SidekiqDaemon.new.alive_state_of(sidekiq))
    end

    def test_dead_pid
      pid = spawn_process('true')
      Process.wait(pid)

      assert_equal(:dead, PumaDaemon.new.alive_state_of(pid))
    end

    # ⚠⚠ **身元が分からないときは生きている扱い**（2 本目を立てない側へ倒す）。
    def test_identity_unavailable
      pid = spawn_process('sleep', '30')
      daemon = PumaDaemon.new
      daemon.define_singleton_method(:process_command) {|_| ''}

      assert_equal(:alive, daemon.alive_state_of(pid))

      daemon.define_singleton_method(:process_command) {|_| raise Errno::ENOENT, 'ps'}

      assert_equal(:alive, daemon.alive_state_of(pid))
    end

    # 受け入れ条件: 別プロセスの PID が入った pid ファイルがあっても起動を拒まない。
    def test_start_is_not_blocked_by_stale_pid_file
      daemon = create_daemon(spawn_titled(SIDEKIQ_TITLE))

      assert_nothing_raised {daemon.send(:abort_if_running!)}
      assert_false(daemon.alive?)
    end

    # 受け入れ条件: 自分のデーモンが生きているときは従来どおり二重起動を拒む。
    def test_start_is_blocked_by_own_process
      daemon = create_daemon(spawn_titled(PUMA_TITLE))

      assert_raise(SystemExit) {silence_stderr {daemon.send(:abort_if_running!)}}
      assert_predicate(daemon, :alive?)
    end

    # ⚠ `restart` は :dead なら停止を飛ばす。**他人のプロセスへ TERM を送らない**ための前提。
    def test_restart_does_not_signal_foreign_process
      pid = spawn_titled(SIDEKIQ_TITLE)
      daemon = create_daemon(pid)

      assert_equal(:dead, daemon.alive_state)
      assert_equal(:alive, Process.alive_state(pid))
    end

    # 🔴 `stop` は他人のプロセスへシグナルを送らず、古い pid ファイルだけを片付ける。
    # 2026-10-06 に dev26 で、Mastodon の puma を実際に止めてしまった形。
    def test_stop_does_not_signal_foreign_process
      pid = spawn_titled('puma 8.0.2 (tcp://127.0.0.1:3000) [mastodon]')
      daemon = create_daemon(pid)
      signals = []
      daemon.define_singleton_method(:send_signal) {|*args| signals.push(args)}

      assert_nothing_raised {silence_stderr {daemon.send(:run_stop)}}
      assert_empty(signals)
      assert_equal(:alive, Process.alive_state(pid))
      assert_false(File.exist?(daemon.pid_file))
    end

    # ⚠ 自分のデーモンには従来どおり TERM を送り、pid ファイルを消す。
    def test_stop_signals_own_process
      pid = spawn_titled(PUMA_TITLE)
      daemon = create_daemon(pid)
      signals = []
      daemon.define_singleton_method(:send_signal) {|*args| signals.push(args)}

      silence_stderr {daemon.send(:run_stop)}

      assert_equal([['TERM', pid]], signals)
      assert_false(File.exist?(daemon.pid_file))
    end

    # ⚠ 身元が分からないときは上流の挙動のまま（止めにいく）。
    def test_stop_with_identity_unavailable
      pid = spawn_process('sleep', '30')
      daemon = create_daemon(pid)
      signals = []
      daemon.define_singleton_method(:send_signal) {|*args| signals.push(args)}
      daemon.define_singleton_method(:process_command) {|_| ''}

      silence_stderr {daemon.send(:run_stop)}

      assert_equal([['TERM', pid]], signals)
    end

    private

    # ⚠ 実機の pid ファイル（`tmp/pids/PumaDaemon.pid`）を踏まないよう、名前を変えて作る。
    def create_daemon(pid)
      daemon = PumaDaemon.new(application: "DaemonIdentityTest#{Process.pid}")
      FileUtils.mkdir_p(File.dirname(daemon.pid_file))
      File.write(daemon.pid_file, pid.to_s)
      @files.push(daemon.pid_file)
      return daemon
    end

    def spawn_process(*)
      pid = Process.spawn(*, out: File::NULL, err: File::NULL)
      @pids.push(pid)
      return pid
    end

    # proctitle を書き換えたプロセスを立て、`ps` から見えるようになるまで待つ。
    def spawn_titled(title)
      pid = spawn_process(RbConfig.ruby, '-e', 'Process.setproctitle(ARGV.first); sleep 30', title)
      deadline = Time.now + WAIT_SECONDS
      until `ps -ww -o command= -p #{pid}`.include?(title)
        raise "proctitle not set: #{title}" if deadline < Time.now
        sleep 0.05
      end
      return pid
    end

    def silence_stderr
      original = $stderr
      $stderr = StringIO.new
      yield
    ensure
      $stderr = original
    end
  end
end
