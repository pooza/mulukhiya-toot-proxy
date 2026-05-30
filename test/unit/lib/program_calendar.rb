module Mulukhiya
  class ProgramCalendarTest < TestCase
    def setup
      @now = Time.new(2026, 5, 30, 12, 0, 0, '+09:00') # 2026-05-30 12:00 JST = 03:00 UTC
      @data = {
        # 08:30 JST は now (12:00) を過ぎている → 翌日へ送られる
        'aired' => {
          'series' => 'プリキュア', 'episode' => 12, 'episode_suffix' => '話',
          'subtitle' => '決戦', 'start_time' => '08:30', 'minutes' => 60,
          'air' => true, 'enable' => true
        },
        # 23:00 JST は now より後 → 当日。minutes 未設定 → 既定 30 分
        'late' => {'series' => '深夜アニメ', 'start_time' => '23:00', 'air' => true, 'enable' => true},
        # episode_suffix 未設定 → 既定「話」
        'nosuffix' => {'series' => '無印', 'episode' => 5, 'start_time' => '15:00', 'air' => true, 'enable' => true},
        # air (エア番組) は抽出条件に含めない。air:false でも有効かつ妥当な
        # start_time を持てば出力される。
        'noair' => {'series' => '非エア', 'start_time' => '09:00', 'air' => false, 'enable' => true},
        'disabled' => {'series' => '無効', 'start_time' => '10:00', 'air' => true, 'enable' => false},
        'notime' => {'series' => '時刻なし', 'air' => true, 'enable' => true},
        'badtime' => {'series' => '不正時刻', 'start_time' => '99:99', 'air' => true, 'enable' => true},
      }
    end

    def ics(data = @data)
      return ProgramCalendar.new(data, now: @now).to_ics
    end

    def test_includes_only_enabled_with_valid_start_time
      result = ics

      assert_match(/UID:program-aired@mulukhiya/, result)
      assert_match(/UID:program-late@mulukhiya/, result)
      assert_match(/UID:program-nosuffix@mulukhiya/, result)
      assert_match(/UID:program-noair@mulukhiya/, result) # air は無関係なので出力される
      assert_no_match(/program-disabled/, result)
      assert_no_match(/program-notime/, result)
      assert_no_match(/program-badtime/, result)
    end

    def test_dtstart_future_time_stays_today
      # 23:00 JST > now 12:00 → 当日 23:00 JST = 14:00 UTC
      assert_match(/DTSTART:20260530T140000Z/, ics)
    end

    def test_dtstart_past_time_rolls_to_next_day
      # 08:30 JST < now 12:00 → 翌日 08:30 JST = 当日 23:30 UTC
      assert_match(/DTSTART:20260530T233000Z/, ics)
    end

    def broadcasting_data
      return {
        'aired' => {
          'series' => 'プリキュア', 'start_time' => '08:30', 'minutes' => 60,
          'air' => true, 'enable' => true
        },
      }
    end

    def test_dtstart_keeps_today_event_at_start_minute
      # Codex #4370 P1 回帰: 開始分ちょうど (08:30:01) に取得しても、放送終了
      # (09:30 JST) 前なので当日イベントを維持する。当日 08:30 JST = 前日 23:30 UTC
      now = Time.new(2026, 5, 30, 8, 30, 1, '+09:00')
      result = ProgramCalendar.new(broadcasting_data, now: now).to_ics
      assert_match(/DTSTART:20260529T233000Z/, result)
    end

    def test_dtstart_rolls_after_broadcast_ends
      # 放送終了 (09:30 JST) を過ぎたら翌日へ送る。翌 05-31 08:30 JST = 05-30 23:30 UTC
      now = Time.new(2026, 5, 30, 9, 31, 0, '+09:00')
      result = ProgramCalendar.new(broadcasting_data, now: now).to_ics
      assert_match(/DTSTART:20260530T233000Z/, result)
    end

    def test_dtend_uses_explicit_minutes
      # aired: 翌日 08:30 JST (= 23:30 UTC) + 60 分 = 翌 00:30 UTC
      assert_match(/DTEND:20260531T003000Z/, ics)
    end

    def test_dtend_defaults_to_30_minutes
      # late: minutes 未設定 → 14:00 UTC + 30 分 = 14:30 UTC
      assert_match(/DTEND:20260530T143000Z/, ics)
    end

    def test_dtstamp_uses_injected_now
      # now 12:00 JST = 03:00 UTC
      assert_match(/DTSTAMP:20260530T030000Z/, ics)
    end

    def test_summary_combines_series_episode_subtitle
      assert_match(/SUMMARY:プリキュア 12話 決戦/, ics)
    end

    def test_summary_defaults_episode_suffix
      assert_match(/SUMMARY:無印 5話/, ics)
    end

    def test_summary_series_only_when_no_episode_or_subtitle
      assert_match(/SUMMARY:深夜アニメ\r?\n/, ics)
    end

    def test_empty_data_produces_valid_calendar_without_events
      result = ics({})

      assert_match(/BEGIN:VCALENDAR/, result)
      assert_match(/END:VCALENDAR/, result)
      assert_no_match(/BEGIN:VEVENT/, result)
    end

    def test_renderer_content_type
      assert_equal('text/calendar; charset=UTF-8', ProgramCalendarRenderer.new.type)
    end
  end
end
