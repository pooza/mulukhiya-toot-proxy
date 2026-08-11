module Mulukhiya
  # ロックの外で引いた Annict の結果を、ロックの中の話数に載せてよいかの判定
  # （#4534 / PR #4569 の Codex P2）。
  #
  # ⚠ ProgramTest へは足さない。あちらは livecure? が false の環境で丸ごと omit
  # されるため、番組表を持たないサーバーでは一度も検査されない
  # （[ProgramScalarCoercionTest](program_scalar_coercion.rb) と同じ理由）。
  # ここは I/O を持たない純関数だけを見るので、どの環境でも必ず走る。
  class ProgramAnnictStalenessTest < TestCase
    NEXT_EP = {'annictId' => 123, 'title' => 'サブタイトル'}.freeze

    def applicable?(next_ep, expected, actual)
      return Program.instance.send(:annict_applicable?, next_ep, expected, actual)
    end

    # 素直な系列: 引いた話数と、ロックの中で確定した話数が一致する。
    def test_applies_when_episode_matches
      assert(applicable?(NEXT_EP, 5, 5))
    end

    # ⚠ 本丸。Annict を待っている間に別の +1 が入ると、ロックの中の話数が先へ
    # 進む。ここで載せてしまうと**古い話数のサブタイトルで新しい話数を上書き**
    # する（#4534 で塞いだのと同じ壊れ方）。
    def test_rejects_when_another_increment_slipped_in
      assert_false(applicable?(NEXT_EP, 5, 6))
    end

    # 巻き戻った場合も同様に載せない（手編集で話数を戻した等）。
    def test_rejects_when_episode_went_backwards
      assert_false(applicable?(NEXT_EP, 5, 4))
    end

    # Annict を引けなかった / 対象作品が紐づいていない。
    def test_rejects_without_episode
      assert_false(applicable?(nil, 5, 5))
    end
  end
end
