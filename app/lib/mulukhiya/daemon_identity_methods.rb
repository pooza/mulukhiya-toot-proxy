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
  # 🔴 **`stop` もこの答えを見る**（ginseng-core v2.2.0・pooza/ginseng-core#673）。生きている番号に
  # `:dead` と答えると、`stop` は TERM を送らず、古い pid ファイルだけ消して正常終了する。
  # ⚠⚠ **同じユーザーで動く Mastodon の puma / sidekiq が番号を引いていても、モロヘイヤの停止が
  # Mastodon を止めない。**2026-10-06 に dev26 で、`PumaDaemon.pid` へ Mastodon の puma の番号を
  # 入れて `service mulukhiya-puma restart` を呼び、実際に Mastodon の web が落ちた
  # （当時は `run_stop` をここで上書きして塞いだ。v2.2.0 で上流へ移ったので外した・#4784）。
  # rc.d はこのあと pattern で取り残しを探すので、本物が別に居れば止まる。
  #
  # ⚠ 混ぜる側は `identity_pattern` を持つこと。**rc.d の `mulukhiya_*_pattern`（`config/sample/freebsd/`）
  # より狭い。**あちらは取り残しを広く拾う用途、こちらは他人を自分と誤らない用途（→ `launcher_pattern`）。
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
    #
    # ⚠ **タグは呼ぶ側で区切りごと囲むこと（PR #4802 の Codex P2）。**部分一致だと
    # `mulukhiya-toot-proxy-old` のような別のチェックアウトを自分と見なす。
    #
    # ⚠⚠ **同じユーザーが同じホストで、同じディレクトリ名のチェックアウトを 2 つ動かす構成は
    # 見分けられない**（proctitle にはディレクトリ名しか出ない。listener は相対パスの
    # `bin/listener_daemon.rb start` なので、ディレクトリ名が違っても見分けられない）。
    # その構成では、古い pid ファイルがもう一方のデーモンを指すと従来どおり「already running」に
    # なり、`stop` はそちらへ TERM を送る。**1 ユーザー 1 チェックアウトで使うこと。**
    def identity_tag
      return Regexp.escape(File.basename(Environment.dir))
    end

    # `exec` の直後、proctitle を書き換える前の姿（"ruby .../bin/puma --config <path>"）。
    # ⚠ 設定ファイルはフルパスで渡しているので、**チェックアウトごとに一意**。
    def exec_pattern(*args)
      return /#{args.map {|v| Regexp.escape(v)}.join(' ')}(?:\s|\z)/
    end

    # 起動スクリプトのまま居るプロセス（`exec` の前、および `exec` しない listener）の姿。
    #
    # ⚠⚠ **スクリプト名の部分一致にしない（PR #4802 の Codex P2）。**`vim .../puma_daemon.rb` や
    # `bin/puma_daemon.rb stop` まで自分と見なすと、`stop` がそこへ TERM を送る。
    # ⚠ `restart` も常駐の姿。`restart` は fork した子がそのまま `run_start` へ進むので、
    # 管理画面や `mulukhiya-daemon.sh` から立った listener は `... restart` のまま居続ける。
    # ⚠ rc.d の pattern（`config/sample/freebsd/`）はスクリプト名だけで見ている。あちらは
    # 「取り残しを広く拾う」用途、こちらは「他人を自分と誤らない」用途。
    def launcher_pattern(script)
      return %r{(?:\A|[\s/])#{Regexp.escape(script)} (?:start|restart)(?:\s|\z)}
    end
  end
end
