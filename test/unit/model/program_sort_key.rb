module Mulukhiya
  # 番組表の標準の並び順 (#4540)。Program.sort_key は I/O を持たないクラス
  # メソッドなので、番組表の実データにも controller の livecure? にも依存せず
  # 検証できる。ProgramTest 側に置くと番組表機能を持たない controller で
  # 丸ごと omit され、実質どこでも走らないテストになる。
  class ProgramSortKeyTest < TestCase
    def sorted_keys(entries)
      return entries.sort_by {|key, entry| Program.sort_key(key, entry)}.map(&:first)
    end

    def test_orders_by_next_on_then_start_time
      entries = {
        'c' => {'next_on' => '2026-08-09', 'start_time' => '08:30'},
        'a' => {'next_on' => '2026-08-08', 'start_time' => '20:30'},
        'b' => {'next_on' => '2026-08-08', 'start_time' => '19:00'},
      }

      assert_equal(['b', 'a', 'c'], sorted_keys(entries))
    end

    def test_sends_entries_without_next_on_to_the_tail
      entries = {
        'daily_late' => {'start_time' => '23:00'},
        'dated' => {'next_on' => '2036-12-31', 'start_time' => '23:59'},
        'daily_early' => {'start_time' => '08:00'},
      }

      # 日付なし同士は start_time 順。日付ありより後ろ。
      assert_equal(['dated', 'daily_early', 'daily_late'], sorted_keys(entries))
    end

    def test_sends_unreadable_start_time_to_the_end_of_the_day
      entries = {
        'sexagesimal' => {'next_on' => '2026-08-08', 'start_time' => 73_800},
        'blank' => {'next_on' => '2026-08-08'},
        'valid' => {'next_on' => '2026-08-08', 'start_time' => '21:00'},
      }
      keys = sorted_keys(entries)

      assert_equal('valid', keys.first)
      # 読めない値同士はキーで決まる。並びが揺れないことだけ担保する。
      assert_equal(['blank', 'sexagesimal'], keys.drop(1))
    end

    # 手編集で入った不正値 (`20260808` 等) は「値がある」側として日付群の中に
    # 字句順で混ざる。毎日枠より前に残るので、エディタの警告バッジが目に入る
    # 位置から落ちない。日付として解釈し直したりはしない。
    def test_keeps_invalid_next_on_inside_the_dated_group
      entries = {
        'invalid' => {'next_on' => '20260808', 'start_time' => '08:00'},
        'daily' => {'start_time' => '08:00'},
        'dated' => {'next_on' => '2026-12-31', 'start_time' => '08:00'},
      }

      # '2026-12-31' < '20260808' ('-' < '0')。同じ年の日付なら不正値は後ろへ。
      assert_equal(['dated', 'invalid', 'daily'], sorted_keys(entries))
    end

    def test_is_stable_for_identical_entries
      entry = {'next_on' => '2026-08-08', 'start_time' => '08:00'}
      entries = {'zzz' => entry.dup, 'aaa' => entry.dup, 'mmm' => entry.dup}

      assert_equal(['aaa', 'mmm', 'zzz'], sorted_keys(entries))
    end
  end
end
