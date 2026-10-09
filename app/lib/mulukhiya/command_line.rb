module Mulukhiya
  class CommandLine < Ginseng::CommandLine
    include Package

    # 締切で TERM を送ってから、KILL に切り替えるまでの猶予（秒）。
    # ⚠ ffmpeg は TERM で出力を閉じて終わるので、その時間を残す。
    KILL_GRACE_SECONDS = 2

    # 締切つきの実行 (#4794)。**締切が来たら子プロセスを止めてから `Timeout::Error` を上げる。**
    #
    # 🔴 上流の `exec(timeout:)` は `Timeout.timeout { Open3.capture3(...) }` の形で、締切が来ても
    # `capture3` の後始末が**子プロセスの終了を待つ**ので、例外が上がるのは子が終わった後になる
    # （`sleep 5` に 1 秒の締切で 5.0 秒後。Linux と FreeBSD 15.1 の両方で実測）。
    # ⚠⚠ ffmpeg に渡した締切は一度も効いておらず、締切を超えた変換は**孤児のまま完走するまで
    # CPU を使い**、締切の後に間に合った変換は**出力が出来ているのに失敗**になっていた。
    #
    # ⚠ **プロセスグループごと止める。**`to_s` はシェルを経由しうるので、子の番号だけに送ると
    # シェルだけが死んで本体が残る。
    # ⚠ 締切を渡さない呼び出しは上流のまま。**0 以下も「締切なし」**（`Timeout.timeout(0)` と同じ意味を保つ）。
    # ⚠ pooza/ginseng-core 側が直ったら、この上書きは外す。
    def exec(timeout: nil)
      return super unless deadline?(timeout)
      secs = Time.elapse do
        Bundler.with_unbundled_env {capture_until(timeout)}
      end
      @pid = @status.pid
      @status = @status.to_i
      log_exec(secs, success: @status.zero?)
      return @status
    end

    def response
      parts = stdout.split("\n\n")
      return {body: stdout, type: APIController.default_type} if parts.count < 2
      headers = HTTP.parse_header(parts.shift)
      return {
        body: parts.join("\n\n"),
        type: headers['content-type']&.first || APIController.default_type,
      }
    end

    def self.create(params)
      params = params.deep_symbolize_keys
      command = new(params[:command])
      command.dir = params[:dir] || Environment.dir
      command.env = params[:env] if params[:env]
      return command
    rescue => e
      e.log
      return nil
    end

    private

    def deadline?(timeout)
      return timeout.is_a?(Numeric) && timeout.positive?
    end

    def spawn_args
      return @user ? [sudo_command] : [child_env, to_s]
    end

    def capture_until(timeout)
      deadline = monotonic + timeout
      Open3.popen3(*spawn_args, chdir: dir, pgroup: true) do |stdin, stdout, stderr, waiter|
        stdin.close
        readers = [stdout, stderr].map {|io| Thread.new {io.read}}
        finished = await(waiter, readers, deadline)
        expire!(waiter.pid, timeout) unless finished
        @stdout, @stderr = readers.map(&:value)
        @status = waiter.value
      ensure
        # 🔴 **外から `Thread#kill` で中断されても、子を残さない。**締切の猶予（TERM → KILL）の
        # 途中で外側の締切に切られると、後始末ごと飛ばされる。ここは待たずに KILL する。
        abandon(waiter.pid, readers) unless finished
      end
    end

    # 子の終了と、出力の読み切りを締切まで待つ。間に合えば true。
    #
    # ⚠⚠ **出力を読み切るところまで締切に含める。**先頭が終わっても、パイプを握った子孫
    # （`sh -c 'sleep 30 &'`）が残っていると `read` は戻らない。
    def await(waiter, readers, deadline)
      return false unless waiter.join(remaining(deadline))
      return readers.all? {|reader| reader.join(remaining(deadline))}
    end

    def remaining(deadline)
      return [deadline - monotonic, 0].max
    end

    def expire!(pgid, timeout)
      terminate(pgid)
      raise Timeout::Error, "execution expired (#{timeout}s): #{masked(to_s)}"
    end

    def abandon(pgid, readers)
      signal_group('KILL', pgid) if group_alive?(pgid)
      readers&.each(&:kill)
    end

    # 締切を過ぎた子をプロセスグループごと止める。
    #
    # ⚠⚠ **先頭のプロセスが終わったことを「止まった」と読まない。**`to_s` がシェルを経由すると
    # 先頭はシェルで、TERM で先に死ぬ。TERM を無視する本体がグループに残るので、
    # **グループが空になったか**で見て、残っていれば KILL する。
    # ⚠ 先頭の回収は `popen3` のブロックの出口が行う（ゾンビを残さない）。
    def terminate(pgid)
      signal_group('TERM', pgid)
      deadline = monotonic + KILL_GRACE_SECONDS
      sleep(0.05) while group_alive?(pgid) && monotonic < deadline
      signal_group('KILL', pgid) if group_alive?(pgid)
    end

    def monotonic
      return Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # ⚠ 送る直前に終わっていることがある（`ESRCH`）。そのときは何もしない。
    def signal_group(signal, pgid)
      Process.kill(signal, -pgid)
    rescue Errno::ESRCH
      nil
    rescue Errno::EPERM => e
      @logger.error(error: e, command: masked(to_s), pgid:, signal:)
    end

    # ⚠ 触れない（`EPERM`）は「居る」。居ないと言い切れるのは `ESRCH` だけ。
    def group_alive?(pgid)
      Process.kill(0, -pgid)
      return true
    rescue Errno::ESRCH
      return false
    rescue Errno::EPERM
      return true
    end
  end
end
