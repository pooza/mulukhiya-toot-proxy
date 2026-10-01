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
      # ⚠⚠ **0 以下は先に弾く (#4635 の 6 件目)。**壊れた pid ファイル（空・切り詰め・
      # 非数値）は `to_i` で 0 になり、`Process.kill(0, 0)` は「自プロセスグループ全体
      # への存在確認」として成功する＝ listener が死んでいても `/health` が OK を返し、
      # 実況の窓で死亡を検知できない。負の pid もプロセスグループ宛てになる。
      raise "PID '#{pid}' is invalid" unless pid.positive?
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
