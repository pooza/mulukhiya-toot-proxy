module Mulukhiya
  # デーモンの `/health` が pid の生死をどう報告するか。
  #
  # ⚠ **芯は「触れなかった」を「死んでいる」と断定しないこと**
  # （pooza/ginseng-core#510）。`Errno::EPERM` でも `Process.alive?` は false に
  # なるので、以前は `"was dead"` と原因を誤って伝えていた。
  class DaemonHealthMethodsTest < TestCase
    class Subject
      extend DaemonHealthMethods
    end

    def test_alive_pid_passes
      assert(Subject.assert_pid_alive!(Process.pid))
    end

    def test_dead_pid_says_dead
      error = assert_raise(RuntimeError) {Subject.assert_pid_alive!(unused_pid)}

      assert_match(/was dead/, error.message)
    end

    # ⚠ **`:unknown` も NG のままでよい**（デーモンは `/health` を返すプロセスと
    # 同じユーザーで動くので、触れない＝うちのデーモンではない）。変わるのは
    # 「なぜ NG なのか」の説明だけ。
    def test_foreign_pid_says_not_ours
      omit 'root では EPERM にならない' if Process.uid.zero?
      omit '触れない他ユーザーのプロセスが見つからない' unless (pid = foreign_pid)

      error = assert_raise(RuntimeError) {Subject.assert_pid_alive!(pid)}

      assert_match(/not ours/, error.message)
      # ⚠ 「dead」と言わないことまで見る。ここが退行すると原因の誤報が戻る。
      assert_not_match(/dead/, error.message)
    end

    # ⚠⚠ **0 以下の pid を生きていると言わない (#4635 の 6 件目)。**壊れた pid ファイルは
    # `to_i` で 0 になり、`Process.kill(0, 0)` は自プロセスグループへの存在確認として
    # 成功する。負の pid もプロセスグループ宛てになる。
    def test_non_positive_pid_is_rejected
      [0, -1].each do |pid|
        error = assert_raise(RuntimeError) {Subject.assert_pid_alive!(pid)}

        assert_match(/invalid/, error.message)
      end
    end

    private

    def unused_pid
      (2**15).downto(2) do |pid|
        Process.kill(0, pid)
      rescue Errno::ESRCH
        return pid
      rescue Errno::EPERM # rubocop:disable Lint/SuppressedException
      end
      return nil
    end

    def foreign_pid
      [1, 2].each do |pid|
        Process.kill(0, pid)
      rescue Errno::EPERM
        return pid
      rescue StandardError # rubocop:disable Lint/SuppressedException
      end
      return nil
    end
  end
end
