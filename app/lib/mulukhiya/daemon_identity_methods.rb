module Mulukhiya
  # pid ファイルが指すプロセスが「自分のデーモンか」を確かめるための部品 (#4792)。
  #
  # 🔴 **pid の生存だけでは足りない。**2026-10-04 のダイスキー（vulcan）の OS 再起動で、
  # 残っていた `PumaDaemon.pid` の番号を sidekiq が引き、puma が「already running」で
  # 約 6 分上がらなかった。systemd は `Restart=always` で起動し直し続けるので、
  # ユニットは `active` と表示されたまま `--failed` にも出ない。
  #
  # ⚠⚠ **判定そのものは gem が持つ (#4817・ginseng-core v2.3.0〜・pooza/ginseng-core#676)。**
  # 各デーモンが `process_pattern`（`Regexp`）を宣言すると、gem の `alive_state_of` が `ps` で
  # コマンド行を見て、一致しなければ `:dead` と答える。`stop` も同じ答えを見るので、
  # 他人のプロセスへは TERM を送らず、古い pid ファイルだけ消す（v2.2.0〜）。
  # ⚠ 以前はここに `alive_state_of` / `foreign_process?` / `process_command` と
  # `launcher_pattern` / `exec_pattern` の自前の実装があった。**同名のメソッドをここへ
  # 戻さないこと** — 混ぜた側が勝って、gem の修正が届かなくなる。
  # 🔴 自前の実装は、`exec` の最中の一瞬（コマンド行が `[ruby]` になる）に本物を他人と答えた。
  # gem は `[…]` だけの行を「分からない」＝生きている扱いへ倒す。
  #
  # ⚠ `process_pattern` は **`Regexp` を返すこと**（文字列だと身元を見なくなり、error が 1 行出る）。
  # ⚠ **rc.d の `mulukhiya_*_pattern`（`config/sample/freebsd/`）より狭い。**あちらは取り残しを
  # 広く拾う用途、こちらは他人を自分と誤らない用途。
  module DaemonIdentityMethods
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
  end
end
