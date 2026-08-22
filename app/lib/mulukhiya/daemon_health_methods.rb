module Mulukhiya
  # デーモンの `/health` が pid の生死を見るときの共通処理。
  #
  # ⚠ **「触れなかった」を「死んでいる」と断定しない** (pooza/ginseng-core#510)。
  # 以前は `Process.alive?` の false をそのまま `"was dead"` と報告していたが、
  # `Errno::EPERM`（プロセスは存在するが、シグナルを送る権限が無い）でも false に
  # なるため、**原因を誤って伝えていた**。ginseng-core 1.17.0 の `alive_state` は
  # `:alive` / `:dead` / `:unknown` を返し分けるので、報告もそれに合わせる。
  #
  # ⚠ **`:unknown` も NG のままでよい。**モロヘイヤのデーモンは `/health` を返す
  # プロセスと同じユーザーで動くので、触れないということは **pid が再利用されて
  # 他人のプロセスになっている**＝うちのデーモンは動いていない。変えるのは
  # 「なぜ NG なのか」の説明だけ。
  module DaemonHealthMethods
    def assert_pid_alive!(pid)
      case Process.alive_state(pid)
      when :alive
        return true
      when :dead
        raise "PID '#{pid}' was dead"
      else
        raise "PID '#{pid}' is not ours (signal not permitted)"
      end
    end
  end
end
