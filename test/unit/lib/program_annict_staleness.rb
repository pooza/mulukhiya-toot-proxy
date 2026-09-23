module Mulukhiya
  # ロックの外で引いた Annict の結果を、ロックの中のエントリに載せてよいかの判定
  # （#4534 / PR #4569・#4571 の Codex P2）。
  #
  # ⚠ ProgramTest へは足さない。あちらは livecure? が false の環境で丸ごと omit
  # されるため、番組表を持たないサーバーでは一度も検査されない
  # （[ProgramScalarCoercionTest](program_scalar_coercion.rb) と同じ理由）。
  # ここは I/O を持たない純関数だけを見るので、どの環境でも必ず走る。
  class ProgramAnnictStalenessTest < TestCase
    EPISODE_DATA = {'annictId' => 123, 'title' => 'サブタイトル'}.freeze

    # ロックを取る前に引いた内容（話数・作品 ID・Annict の応答）。
    def prepared(episode: 5, work_id: 42, episode_data: EPISODE_DATA)
      return {episode:, work_id:, episode_data:}
    end

    # ロックの中で確定したエントリ。
    def entry(episode: 5, work_id: 42)
      return {'episode' => episode, 'annict_work_id' => work_id}
    end

    # 判定の実体は #4570 で ProgramEditor へ移した。⚠ **Singleton ではない**ので
    # テストごとに使い捨てのインスタンスを持てる。
    def editor
      @editor ||= ProgramEditor.new
    end

    def applicable?(prepared, entry)
      return editor.send(:annict_applicable?, prepared, entry)
    end

    # 素直な系列: 引いた時点と、ロックの中で確定した内容が一致する。
    def test_applies_when_episode_and_work_match
      assert(applicable?(prepared, entry))
    end

    # ⚠ 本丸その 1。Annict を待っている間に別の +1 が入ると、ロックの中の話数が
    # 先へ進む。ここで載せると**古い話数のサブタイトルで新しい話数を上書き**する
    # （#4534 で塞いだのと同じ壊れ方）。
    def test_rejects_when_another_increment_slipped_in
      assert_false(applicable?(prepared, entry(episode: 6)))
    end

    # 巻き戻った場合も同様に載せない（手編集で話数を戻した等）。
    def test_rejects_when_episode_went_backwards
      assert_false(applicable?(prepared, entry(episode: 4)))
    end

    # ⚠ 本丸その 2。ProgramEntryUpdateContract は annict_work_id の変更を許して
    # いるので、待っている間に作品を差し替えられると**話数は同じだが別作品**に
    # なる。そこへ旧作品のサブタイトルを載せてはいけない (PR #4571 の Codex P2)。
    def test_rejects_when_work_id_was_swapped
      assert_false(applicable?(prepared, entry(work_id: 43)))
    end

    # 作品 ID を外された場合も同様。
    def test_rejects_when_work_id_was_cleared
      assert_false(applicable?(prepared, entry(work_id: nil)))
    end

    # Annict を引けなかった / 対象作品が紐づいていない。
    def test_rejects_without_episode_data
      assert_false(applicable?(prepared(episode_data: nil), entry))
    end

    # --- ガードが効いたことの観測 (#4577 の 3) -------------------------------
    #
    # ⚠⚠ **載せなかった結果は `annict_episode_id: nil` ＝「Annict を引けなかった」
    # ときと同じ状態**なので、ログが無いと両者を区別する手段がゼロになる。
    # 運用者から見ると、どちらも「次話を押して 200 が返り、サブタイトルだけ
    # 入らない」という同じ見え方をする。

    # ⚠ **引けたのに載せられなかった回**だけがガードの発動。
    def test_stale_only_when_data_was_fetched
      assert(stale?(prepared, entry(episode: 6)))
      assert_false(stale?(prepared, entry), '素直に載る回を stale と読んでいる')
      assert_false(
        stale?(prepared(episode_data: nil), entry(episode: 6)),
        'Annict を引けなかった回を「ガードが効いた」と読んでいる',
      )
    end

    # ⚠⚠ 本丸。ガードが効いた回が、**期待値と実値の両方**で残ること。
    # Annict 側の障害なのか競合なのかで、運用者が「`PUT` でメタデータを補う」のか
    # 「Annict の設定を見る」のかが変わる。
    def test_stale_guard_is_logged_with_both_values
      target = entry(episode: 6)
      logged = capture_info {apply('nichiasa', prepared, target)}

      assert_equal(1, logged.size)
      payload = logged.first[:program_entry]

      assert_equal('annict_stale', payload[:event])
      assert_equal('nichiasa', payload[:key])
      assert_equal(5, payload[:prepared_episode])
      assert_equal(6, payload[:actual_episode])
    end

    # 作品を差し替えられた回も、どちらの ID だったかまで残す。
    def test_stale_guard_records_work_ids
      payload = capture_info {apply('k', prepared, entry(work_id: 43))}.first[:program_entry]

      assert_equal(42, payload[:prepared_work_id])
      assert_equal(43, payload[:actual_work_id])
    end

    # ⚠ Annict を引けなかった回は出さない。混ぜると、このログが
    # 「ガードが効いた」の意味を失う。
    def test_missing_episode_data_is_not_logged
      assert_empty(capture_info {apply('k', prepared(episode_data: nil), entry)})
    end

    # 素直に載った回も出さない（毎回出ると観測点にならない）。
    def test_applied_case_is_not_logged
      target = entry
      logged = capture_info {apply('k', prepared, target)}

      assert_empty(logged)
      assert_equal(123, target['annict_episode_id'])
      assert_equal('サブタイトル', target['subtitle'])
    end

    # ⚠ 載せない回は `annict_episode_id` を必ず nil へ落とす。前回の値が残ると、
    # **新しい話数に古い Annict の ID が付いたまま**になる。
    def test_stale_clears_previous_annict_id
      target = entry(episode: 6).merge('annict_episode_id' => 999)
      capture_info {apply('k', prepared, target)}

      assert_nil(target['annict_episode_id'])
    end

    private

    def stale?(prepared, entry)
      return editor.send(:annict_stale?, prepared, entry)
    end

    def apply(key, prepared, entry)
      return editor.send(:apply_annict_increment, key, prepared, entry)
    end

    # ⚠ 差し替え先は**このテスト専用の ProgramEditor**（#4570）。以前は
    # `Program.instance` の singleton へ生やしており、外し忘れると以降のテストの
    # ログが全部ここへ流れ込む形だった。使い捨てのインスタンスになったので
    # その事故は起こらないが、対称性のため ensure で外すのは残す。
    def capture_info
      logged = []
      double = Object.new
      double.define_singleton_method(:info) {|payload| logged.push(payload)}
      editor.define_singleton_method(:logger) {double}
      begin
        yield
      ensure
        editor.singleton_class.send(:remove_method, :logger)
      end
      return logged
    end
  end
end
