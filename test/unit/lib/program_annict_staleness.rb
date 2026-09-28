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
    def prepared(episode: 5, work_id: 42, episode_data: EPISODE_DATA, state: nil)
      return {episode:, work_id:, episode_data:, state:}
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

    # ⚠ **引けたのに載せられなかった回**だけがガードの発動 (`superseded`)。
    # 戻り値はレスポンスの `annict` になる (#4579)。
    def test_state_is_superseded_only_when_data_was_fetched
      capture_info do
        assert_equal(:superseded, apply('k', prepared, entry(episode: 6)))
        assert_equal(:applied, apply('k', prepared, entry), '素直に載る回を superseded と読んでいる')
        assert_equal(
          :failed,
          apply('k', prepared(episode_data: nil, state: :failed), entry(episode: 6)),
          'Annict を引けなかった回を「ガードが効いた」と読んでいる',
        )
      end
    end

    # --- 載せなかった理由の判定 (#4579) --------------------------------------
    #
    # ⚠⚠ 以前はレスポンスの形が 3 通りとも同じで、クライアントには区別がつかなかった。

    def test_prepare_is_unconfigured_without_annict
      stub_data('k' => {'episode' => 4, 'annict_work_id' => 42})

      assert_equal(:unconfigured, prepare('k', nil)[:state])
    end

    def test_prepare_is_unconfigured_without_work_id
      stub_data('k' => {'episode' => 4})

      assert_equal(:unconfigured, prepare('k', annict_double([]))[:state])
    end

    def test_prepare_finds_the_next_episode
      stub_data('k' => {'episode' => 4, 'annict_work_id' => 42})
      result = prepare('k', annict_double([{'numberText' => '第5話', 'annictId' => 123}]))

      assert_nil(result[:state])
      assert_equal(123, result[:episode_data]['annictId'])
    end

    def test_prepare_is_not_found_when_annict_lacks_the_episode
      stub_data('k' => {'episode' => 4, 'annict_work_id' => 42})

      assert_equal(:not_found, prepare('k', annict_double([{'numberText' => '第4話'}]))[:state])
    end

    # ⚠ Annict の障害を `not_found` と混ぜない。クライアントが取る手が違う
    # （`not_found` は Annict 側にまだ無い、`failed` は時間を置けば引ける）。
    def test_prepare_is_failed_when_annict_raises
      stub_data('k' => {'episode' => 4, 'annict_work_id' => 42})
      error = RuntimeError.new('annict down')
      error.define_singleton_method(:log) {|*| nil}
      annict = Object.new
      annict.define_singleton_method(:episodes) {|_ids, **| raise error}

      assert_equal(:failed, prepare('k', annict)[:state])
    end

    # 🔴 **同期の `alert` を撃たない (#4760)。**通知先を待つ間にクライアントが再送すると
    # 話数が 2 つ進む。失敗はログに残ること。
    def test_prepare_does_not_alert_when_annict_raises
      stub_data('k' => {'episode' => 4, 'annict_work_id' => 42})
      calls = []
      error = RuntimeError.new('annict down')
      error.define_singleton_method(:alert) {|*| calls.push(:alert)}
      error.define_singleton_method(:log) {|payload| calls.push(payload)}
      annict = Object.new
      annict.define_singleton_method(:episodes) {|_ids, **| raise error}
      prepare('k', annict)

      assert_not_include(calls, :alert)
      assert_equal('annict_failed', calls.first[:program_entry][:event])
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

    # --- Annict にまだ無い話数では断る (#4771) --------------------------------
    #
    # ⚠ 放送直後に押すと翌週の回が Annict に未登録で、以前は話数だけ進んで
    # サブタイトルを手で補うことになっていた。断れば、押し直すだけで一度に入る。

    def test_increment_refuses_when_annict_lacks_the_episode
      programs = stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42})
      error = assert_raise(ConflictError) do
        editor.increment_episode_with_annict('k', annict: annict_double([{'numberText' => '第4話'}]))
      end

      assert_equal(:annict_not_found, error.code)
      assert_nil(error.retry_after, 'Annict に載る時刻は分からないので Retry-After を付けない')
      assert_equal(4, programs['k']['episode'], '断ったのに話数が進んでいる')
      assert_empty(@saved, '断ったのに保存している')
    end

    # ⚠ Annict の障害では断らない（2026-09-26 ユーザー判断）。作業が止まらないように、
    # 今までどおり +1 して `failed` を返す。
    def test_increment_proceeds_when_annict_fails
      stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42})
      error = RuntimeError.new('annict down')
      error.define_singleton_method(:log) {|*| nil}
      annict = Object.new
      annict.define_singleton_method(:episodes) {|_ids, **| raise error}
      result = editor.increment_episode_with_annict('k', annict:)

      assert_equal(:failed, result[:annict])
      assert_equal(5, result[:entry]['episode'])
      assert_equal(1, @saved.size)
    end

    # 作品 ID が無い番組は Annict を見ないので、今までどおり +1 する。
    def test_increment_proceeds_without_work_id
      stub_increment('k' => {'episode' => 4})
      result = editor.increment_episode_with_annict('k', annict: annict_double([]))

      assert_equal(:unconfigured, result[:annict])
      assert_equal(5, result[:entry]['episode'])
    end

    # ⚠ 無いキーは 404 のまま。断る判定をロックの外に置くと、ここが 409 に化ける。
    def test_increment_on_missing_key_is_still_not_found
      stub_increment({})

      assert_raise(Ginseng::NotFoundError) do
        editor.increment_episode_with_annict('nothing', annict: annict_double([]))
      end
    end

    # ⚠ 引いている間に別の +1 が入っていたら、`not_found` は古い話数についての答え。
    # 断らずに +1 し、`superseded` として報告する（PR #4776 の Codex P2）。
    # ここでは「引いた後にエントリが 5 へ進んだ」を、data の差し替えで再現する。
    def test_increment_does_not_refuse_on_stale_miss
      programs = stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42})
      annict = Object.new
      annict.define_singleton_method(:episodes) do |_ids, **|
        programs['k']['episode'] = 5 # 引いている間に別の +1 が入った
        next [{'numberText' => '第4話'}]
      end
      result = capture_info {@result = editor.increment_episode_with_annict('k', annict:)}

      assert_equal(:superseded, @result[:annict])
      assert_equal(6, @result[:entry]['episode'])
      assert_equal('annict_stale', result.first[:program_entry][:event])
    end

    # 作品を差し替えられた場合も同じ。
    def test_increment_does_not_refuse_when_work_was_swapped
      programs = stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42})
      annict = Object.new
      annict.define_singleton_method(:episodes) do |_ids, **|
        programs['k']['annict_work_id'] = 43
        next []
      end
      capture_info {@result = editor.increment_episode_with_annict('k', annict:)}

      assert_equal(:superseded, @result[:annict])
      assert_equal(5, @result[:entry]['episode'])
    end

    # ⚠ 回は登録済みだがサブタイトルがまだ無い（PR #4776 の Codex P2）。断ると、
    # サブタイトルを持たない作品では「話数 ＋」がずっと通らなくなる。+1 して `untitled` を返す。
    def test_increment_proceeds_when_episode_has_no_title
      programs = stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42, 'subtitle' => '前の回'})
      calls = []
      annict = Object.new
      annict.define_singleton_method(:episodes) do |_ids, **opts|
        calls.push(opts)
        next [{'numberText' => '第5話', 'annictId' => 123, 'title' => nil}]
      end
      result = editor.increment_episode_with_annict('k', annict:)

      assert_equal(:untitled, result[:annict])
      assert_equal(5, programs['k']['episode'])
      assert_equal(123, programs['k']['annict_episode_id'])
      assert_equal([{untitled: true}], calls, 'サブタイトルの無い回を落として引いている')
    end

    def test_increment_applies_when_annict_has_the_episode
      stub_increment('k' => {'episode' => 4, 'annict_work_id' => 42})
      annict = annict_double([{'numberText' => '第5話', 'annictId' => 123, 'title' => 'サブタイトル'}])
      result = editor.increment_episode_with_annict('k', annict:)

      assert_equal(:applied, result[:annict])
      assert_equal(5, result[:entry]['episode'])
      assert_equal('サブタイトル', result[:entry]['subtitle'])
    end

    private

    # increment_episode_with_annict を Redis・YAML 抜きで通すための差し替え。
    # ロックは素通し、保存は記録するだけ。
    def stub_increment(programs)
      stub_data(programs)
      @saved = []
      saved = @saved
      editor.define_singleton_method(:auto_update?) {false}
      lock = Object.new
      lock.define_singleton_method(:synchronize) {|&block| block.call}
      editor.define_singleton_method(:lock) {lock}
      fetcher = Object.new
      fetcher.define_singleton_method(:save) {|values| saved.push(values)}
      editor.define_singleton_method(:fetcher) {fetcher}
      return programs
    end

    def prepare(key, annict)
      return editor.send(:prepare_annict_increment, key, annict)
    end

    def stub_data(programs)
      editor.define_singleton_method(:data) {programs}
    end

    def annict_double(episodes)
      annict = Object.new
      annict.define_singleton_method(:episodes) {|_ids, **| episodes}
      return annict
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
