module Mulukhiya
  # 締切つきの `exec` は、締切の時点で子プロセスを止める (#4794)。
  #
  # 🔴 上流の `Timeout.timeout { Open3.capture3(...) }` は、締切が来ても子の終了を待ってから
  # 例外を上げる。ffmpeg に渡した締切が一度も効いておらず、締切を超えた変換は孤児のまま完走し、
  # 締切の後に間に合った変換は出力が出来ているのに失敗になっていた。
  class CommandLineDeadlineTest < TestCase
    def test_raises_at_deadline_and_kills_child
      nap = unique_sleep
      command = CommandLine.new(['sh', '-c', nap])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_raise(Timeout::Error) {command.exec(timeout: 0.5)}
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_operator(elapsed, :<, 5, '締切で戻っていない（子の終了を待っている）')
      assert_empty(running(nap), '子プロセスが残っている')
    end

    # ⚠ シェルが立てた孫まで止める（子の番号だけに送ると本体が残る）。
    def test_kills_grandchild_started_by_shell
      nap = unique_sleep
      command = CommandLine.new(['sh', '-c', "(#{nap}; echo done) & wait"])

      assert_raise(Timeout::Error) {command.exec(timeout: 0.5)}
      assert_empty(running(nap), '孫プロセスが残っている')
    end

    # ⚠ TERM を無視する相手は、猶予のあと KILL で止める。
    def test_escalates_to_kill
      nap = unique_sleep
      command = CommandLine.new(['sh', '-c', "trap '' TERM; #{nap}; #{nap}"])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_raise(Timeout::Error) {command.exec(timeout: 0.5)}
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_operator(elapsed, :<, 10)
      assert_empty(running(nap))
    end

    # 締切の前に終わったものは成功し、出力・状態・pid が取れる（上流と同じ見え方）。
    def test_finishes_before_deadline
      command = CommandLine.new(['sh', '-c', 'echo out; echo err >&2; exit 3'])

      upstream = CommandLine.new(command.args)
      upstream.exec

      assert_equal(upstream.status, command.exec(timeout: 10))
      assert_false(command.status.zero?)
      assert_equal("out\n", command.stdout)
      assert_equal("err\n", command.stderr)
      assert_kind_of(Integer, command.pid)
    end

    # ⚠ パイプのバッファ（64KB）を超える出力でも詰まらない。
    def test_large_output_does_not_block
      command = CommandLine.new(['sh', '-c', 'head -c 300000 /dev/zero | tr "\\0" a'])

      assert_equal(0, command.exec(timeout: 10))
      assert_equal(300_000, command.stdout.bytesize)
    end

    # ⚠ 締切を渡さない呼び出しは上流のまま。
    def test_without_timeout_uses_upstream
      command = CommandLine.new(['echo', 'ok'])

      assert_equal(0, command.exec)
      assert_equal("ok\n", command.stdout)
    end

    private

    # ⚠ 秒数を毎回変えて、そのテストが立てた `sleep` だけを数えられるようにする。
    def unique_sleep
      return "sleep 30.#{SecureRandom.random_number(10**8).to_s.rjust(8, '0')}"
    end

    # ⚠ KILL はグループへ送った時点で戻る。孫が消えるまでの一瞬を待ってから数える。
    def running(command)
      pids = []
      20.times do
        pids = `pgrep -f '^#{command}$'`.split
        break if pids.empty?
        sleep(0.1)
      end
      return pids
    end
  end
end
