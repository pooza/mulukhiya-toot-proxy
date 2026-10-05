require 'open3'

module Mulukhiya
  # pid ファイルが指すプロセスが「自分のデーモンか」を確かめる (#4792)。
  #
  # 🔴 **pid の生存だけでは足りない。**2026-10-04 のダイスキー（vulcan）の OS 再起動で、
  # 残っていた `PumaDaemon.pid` の番号を sidekiq が引き、puma が「already running」で
  # 約 6 分上がらなかった。systemd は `Restart=always` で起動し直し続けるので、
  # ユニットは `active` と表示されたまま `--failed` にも出ない。
  #
  # ⚠⚠ **正常停止でも pid ファイルは残りうる。**`Ginseng::Daemon#run_start` は TERM の
  # trap で pid ファイルを消すが、puma / sidekiq は `start` が `exec` するので、
  # **trap は置き換わった時点で消える。**systemd のユニットは TERM を直接送る
  # （`ExecStop=/bin/kill -TERM $MAINPID`）ので毎回残る。rc.d は `bin/*_daemon.rb stop` を
  # 通すので消える（`run_stop` が消す）が、kill -9 や電源断では同じく残る。
  # ＝ **残さないことは保証できないので、残っても起動を妨げない側で閉じる。**
  #
  # ⚠ **上書きするのは `alive_state` ではなく `alive_state_of`**（pooza/ginseng-core#638）。
  # pid ファイルを読み直さないため。
  #
  # ⚠ 混ぜる側は `identity_pattern` を持つこと。**rc.d の `mulukhiya_*_pattern` と
  # 同じ物差し**にしてある（`config/sample/freebsd/`）。
  module DaemonIdentityMethods
    def alive_state_of(found)
      state = super
      return state unless state == :alive
      return :alive unless foreign_process?(found)
      @logger.info(
        daemon: app_name,
        message: 'pid file points to another process',
        pid: found,
        pid_file:,
      )
      return :dead
    end

    # その pid は自分のデーモンではないと言い切れるか。
    #
    # ⚠⚠ **分からないときは false（＝生きている扱い）へ倒す。**ここで true を返すと
    # `start` が pid ファイルを取り直して 2 本目を立てる。「上がらない」は外から見えるが、
    # **sidekiq の二重起動は黙って進む**ので、迷ったら起動しない側に置く。
    def foreign_process?(pid)
      command = process_command(pid)
      return false if command.empty?
      return !identity_pattern.match?(command)
    rescue => e
      @logger.error(error: e, daemon: app_name, message: 'process identity unavailable', pid:)
      return false
    end

    # ⚠ `/proc` は FreeBSD では既定でマウントされていないので、両方で通る `ps` を使う。
    # `-ww` は幅で切られないようにするため（パターンの後半が落ちると他人と誤る）。
    def process_command(pid)
      out, status = Open3.capture2('ps', '-ww', '-o', 'command=', '-p', pid.to_s, err: File::NULL)
      return '' unless status.success?
      return out.strip
    end

    # puma / sidekiq の proctitle に入るタグ（作業ディレクトリの名前）。
    def identity_tag
      return Regexp.escape(File.basename(Environment.dir))
    end
  end
end
