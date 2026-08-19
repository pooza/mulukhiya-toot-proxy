module Mulukhiya
  # var/program.yaml の next_on 正規化 (#4558)。
  #
  # ⚠ **ProgramTest とは分けてある。**あちらは `controller_class.livecure?` が
  # false だとクラスごと omission になり、CI には var/program.yaml も
  # /program/urls も無いので常に false（#4585 で踏んだ）。ここで見るのは
  # 「YAML のテキストをどう読むか」だけで実データも Redis も要らないため、
  # 常に実走させる（#4503 の「守れているつもりの緑」を作らない）。
  class ProgramYAMLNormalizeTest < TestCase
    def setup
      @fetcher = ProgramFetcher.new
    end

    # ゾーンレスの手書き。Psych は UTC として読むので、素の strftime では
    # 翌日になる。書いたとおりの日付が返ること (#4537 の意図)。
    def test_zoneless_timestamp_keeps_written_date
      assert_equal('2026-08-08', next_on('2026-08-08 18:00:00'))
    end

    def test_zoneless_late_night_timestamp_keeps_written_date
      assert_equal('2026-08-08', next_on('2026-08-08 23:30:00'))
    end

    # ⚠ **本命の回帰 (#4558 項目 2)。**明示オフセット付きは getutc で 1 日前へ
    # ずれていた（`2026-08-08 00:30:00 +09:00` → `2026-08-07`）。深夜アニメの枠を
    # 素直に書くと踏む形。
    def test_explicit_offset_timestamp_keeps_written_date
      assert_equal('2026-08-08', next_on('2026-08-08 00:30:00 +09:00'))
    end

    # 負のオフセットは逆方向へずれていた。
    def test_negative_offset_timestamp_keeps_written_date
      assert_equal('2026-08-08', next_on('2026-08-08 22:00:00 -05:00'))
    end

    def test_iso8601_timestamp_keeps_written_date
      assert_equal('2026-08-08', next_on('2026-08-08T00:30:00+09:00'))
    end

    def test_plain_date_becomes_string
      assert_equal('2026-08-08', next_on('2026-08-08'))
    end

    def test_quoted_date_is_unchanged
      assert_equal('2026-08-08', next_on("'2026-08-08'"))
    end

    # ⚠ **本命の回帰 (#4558 項目 1)。**Time のままキャッシュへ入れると
    # `to_json` が `to_s` 相当で書き出すため、2 回目以降の読み出しで
    # `"2026-08-08 18:00:00 +0900"` という日付として読めない値になっていた。
    # Redis 往復と同じ JSON の往復で値が変わらないこと。
    def test_survives_json_round_trip
      programs = parse("a:\n  next_on: 2026-08-08 18:00:00\n")

      assert_equal(programs, JSON.parse(programs.to_json))
      assert_equal('2026-08-08', JSON.parse(programs.to_json).dig('a', 'next_on'))
    end

    # 日付として読めない値は触らない。壊れた値を別の壊れた値へ書き換えず、
    # 判定は contract / ProgramCalendar に任せる。
    def test_leaves_non_date_scalar
      assert_equal(20_260_808, next_on('20260808'))
      assert_equal('毎週日曜', next_on('毎週日曜'))
    end

    # 実在しない日付も素通し（エディタが「不正」バッジを出す側の担当）。
    def test_leaves_impossible_date
      assert_equal('2026-02-31', next_on('2026-02-31'))
    end

    # ⚠ **日付で始まるだけの壊れた値を、有効な日付へ「直して」しまわないこと**
    # (PR #4607 の Codex P2)。これらは Psych も Time にできず String のまま残る値で、
    # ProgramCalendar は fail-closed していた。書き換えると意図しない話数を
    # 予告・通知しうる。
    def test_leaves_date_with_garbage_suffix
      assert_equal('2026-08-08 garbage', next_on('2026-08-08 garbage'))
    end

    def test_leaves_out_of_range_time
      assert_equal('2026-08-08 25:99:99', next_on('2026-08-08 25:99:99'))
    end

    # 秒が無い形は Psych も Time にしない（＝日付として確定していない）。
    def test_leaves_time_without_seconds
      assert_equal('2026-08-08 18:00', next_on('2026-08-08 18:00'))
    end

    # ⚠ 逆に、Psych が Time にできる形は取りこぼさないこと。
    def test_normalizes_fractional_seconds_with_offset
      assert_equal('2026-08-08', next_on('2026-08-08 18:00:00.123 +09:00'))
    end

    def test_normalizes_zulu_timestamp
      assert_equal('2026-08-08', next_on('2026-08-08 18:00:00Z'))
    end

    def test_normalizes_compact_offset
      assert_equal('2026-08-08', next_on('2026-08-08t18:00:00+0900'))
    end

    # ⚠ **潰すのは next_on だけ。**start_time の 60 進数解釈 (`20:30` → 73800) は
    # Program#coerce_scalars の担当なので、ここで型を変えてはいけない。
    def test_keeps_other_keys_untouched
      entry = parse("a:\n  next_on: 2026-08-08\n  start_time: 20:30\n  series: A\n")['a']

      assert_equal(73_800, entry['start_time'])
      assert_equal('A', entry['series'])
    end

    def test_entry_without_next_on_is_kept
      assert_equal({'series' => 'A'}, parse("a:\n  series: A\n")['a'])
    end

    def test_empty_source_becomes_empty_hash
      assert_empty(parse(''))
      assert_empty(parse("---\n"))
    end

    private

    def parse(source)
      return @fetcher.send(:parse_yaml, source)
    end

    def next_on(value)
      return parse("a:\n  next_on: #{value}\n").dig('a', 'next_on')
    end
  end
end
