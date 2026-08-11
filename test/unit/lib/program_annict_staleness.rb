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

    def applicable?(prepared, entry)
      return Program.instance.send(:annict_applicable?, prepared, entry)
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
  end
end
