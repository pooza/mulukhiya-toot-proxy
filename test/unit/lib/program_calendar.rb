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

    # ---- next_on (次回放送日) ---- (#4373)
    #
    # 曜日ルールを持たないので、ウィークリー枠は next_on で「次はいつか」だけを
    # 指す。**過ぎたら出力しない**（fail-closed）のが肝で、翌日へ送ってしまうと
    # 週次枠が毎日誤発火する従来の不具合に戻る。

    def weekly(next_on, start_time: '20:30', minutes: 60)
      return {
        'weekly' => {
          'series' => '振り返り実況', 'episode' => 3, 'start_time' => start_time,
          'minutes' => minutes, 'next_on' => next_on, 'enable' => true
        },
      }
    end

    # 正のケース: 未来の next_on はその日に 1 件出る。
    def test_next_on_future_emits_event_on_that_date
      # 2026-06-06 (土) 20:30 JST = 11:30 UTC
      result = ics(weekly('2026-06-06'))

      assert_match(/UID:program-weekly@mulukhiya/, result)
      assert_match(/DTSTART:20260606T113000Z/, result)
      assert_match(/SUMMARY:振り返り実況 3話/, result)
    end

    # ⚠ ここが本体。過ぎた next_on は**翌日へ送らず消える**。
    def test_next_on_past_emits_nothing
      result = ics(weekly('2026-05-23'))

      assert_no_match(/BEGIN:VEVENT/, result)
      assert_no_match(/program-weekly/, result)
    end

    # 当日の放送中は残す（#4287 の取り逃し防止と同じ扱い）。
    def test_next_on_today_keeps_event_while_broadcasting
      # now は 12:00。11:30 開始 60 分なので 12:30 まで放送中
      result = ics(weekly('2026-05-30', start_time: '11:30', minutes: 60))

      assert_match(/DTSTART:20260530T023000Z/, result)
    end

    # 当日でも終了済みなら消える（翌日へは送らない）。
    def test_next_on_today_disappears_after_end
      result = ics(weekly('2026-05-30', start_time: '08:30', minutes: 60))

      assert_no_match(/BEGIN:VEVENT/, result)
    end

    # next_on 未設定は従来どおり毎日扱い。既存枠の移行を不要にするための保証。
    def test_without_next_on_keeps_daily_behaviour
      result = ics

      assert_match(/DTSTART:20260530T140000Z/, result) # late 23:00 当日
      assert_match(/DTSTART:20260530T233000Z/, result) # aired 08:30 翌日
    end

    # 落ちたエントリのログ (#4537)。next_on を過ぎて出力から消えたことを、
    # 番組表エディタの警告バッジ以外でも検知できるようにする。
    def warnings(data)
      calendar = ProgramCalendar.new(data, now: @now)
      logged = []
      calendar.send(:logger).define_singleton_method(:warn) {|message| logged.push(message)}
      calendar.to_ics
      return logged
    end

    # ⚠ ここが本体。黙って落とすと実況が沈黙したことに誰も気づけない。
    # .ics は tomato-shrieker が定期 GET するので、放置されていれば日次で出る。
    def test_expired_next_on_is_logged
      logged = warnings(weekly('2026-05-23'))

      assert_equal(1, logged.size)
      assert_equal('program next_on expired', logged.first[:message])
      assert_equal('2026-05-23', logged.first[:next_on])
      assert_equal('weekly', logged.first[:key])
    end

    # 書式違反は scheduled_date が既に error を出している。warn を重ねない
    # (同じ事象で 2 行出すとどちらも読まれなくなる)。
    def test_invalid_next_on_is_not_warned
      assert_empty(warnings(weekly('2026/08/08', start_time: '23:00')))
    end

    # 出力されたエントリでは鳴らさない。毎回鳴るログは読まれなくなる。
    def test_future_next_on_is_not_warned
      assert_empty(warnings(weekly('2026-06-06')))
    end

    # 毎日枠 (next_on 未設定) は落ちないので鳴らない。
    def test_daily_entries_are_not_warned
      assert_empty(warnings(@data))
    end

    # ⚠ 不正な日付は**毎日扱いへ倒さない**。倒すと「日付を間違えた」が
    # 「古い話数で毎日鳴る」に化け、曜日ルールを却下した理由がそのまま当たる。
    # 番組表全体は落とさず、そのエントリだけ黙る。
    def test_invalid_next_on_emits_nothing
      result = ics(weekly('2026-02-31', start_time: '23:00'))

      assert_no_match(/program-weekly/, result)
    end

    # 書式違い（YAML 手編集で `2026/08/08` と書く等）も同じく黙る。
    def test_malformed_next_on_emits_nothing
      result = ics(weekly('2026/08/08', start_time: '23:00'))

      assert_no_match(/program-weekly/, result)
    end

    # 文字列ですらない値（`next_on: 20260808` は Integer で入る）も黙る。
    def test_non_string_next_on_emits_nothing
      result = ics(weekly(20_260_808, start_time: '23:00'))

      assert_no_match(/program-weekly/, result)
    end

    # ⚠ Date.strptime は寛容で末尾のゴミやゼロ埋め無しを通す。素で渡すと
    # 「不正なのにイベントが出る」に戻る (Codex P2 / PR #4529)。
    def test_lenient_next_on_emits_nothing
      ['2026-08-08junk', '2026-8-8', ' 2026-08-08', '2026-08-08 '].each do |value|
        assert_no_match(/program-weekly/, ics(weekly(value, start_time: '23:00')), "#{value} を通している")
      end
    end

    # 空文字は「未設定」と同じ。日付を消す操作を毎日扱いへ戻すため。
    def test_blank_next_on_falls_back_to_daily
      result = ics(weekly('', start_time: '23:00'))

      assert_match(/DTSTART:20260530T140000Z/, result)
    end

    # 番組表全体を巻き込まないこと（不正エントリ以外は従来どおり出る）。
    def test_invalid_next_on_keeps_other_entries
      result = ics(@data.merge(weekly('2026-02-31', start_time: '23:00')))

      assert_no_match(/program-weekly/, result)
      assert_match(/DTSTART:20260530T233000Z/, result) # aired 08:30 翌日
    end

    # ---- DESCRIPTION (説明) ---- (#4541)

    def described(description: nil, extra_tags: nil)
      entry = {'series' => '振り返り実況', 'start_time' => '23:00', 'enable' => true}
      entry['description'] = description unless description.nil?
      entry['extra_tags'] = extra_tags unless extra_tags.nil?
      return {'weekly' => entry}
    end

    def test_description_is_emitted_when_set
      result = ics(described(description: '実況は 5 分前集合'))

      assert_match(/DESCRIPTION:実況は 5 分前集合/, result)
    end

    # 説明が無いときは extra_tags をハッシュタグ行として出す。
    def test_description_falls_back_to_hashtags
      result = ics(described(extra_tags: ['プリキュア', 'YouTube']))

      assert_match(/DESCRIPTION:#プリキュア #YouTube/, result)
    end

    # 既に # が付いている値は二重にしない。
    def test_hashtags_are_not_double_prefixed
      result = ics(described(extra_tags: ['#プリキュア']))

      assert_match(/DESCRIPTION:#プリキュア\r?\n/, result)
      assert_no_match(/DESCRIPTION:##/, result)
    end

    # ⚠ `#` を素で前置しない。約物の扱いは Mastodon (`_ · ・ ZWNJ` 以外を削除) と
    # Misskey (無加工) で割れるので、素のままだと両系で別のタグに落ちる。
    # to_hashtag が非英数字を一律 `_` へ寄せた形だけが、双方を無変換で通る。
    def test_hashtags_are_normalized_through_to_hashtag
      # ⚠ 75 オクテットで折り返されるので、1 行に収まる長さで確かめる。
      result = ics(described(extra_tags: ['名探偵プリキュア！', 'ふたり・はぐ']))

      assert_match(/DESCRIPTION:#名探偵プリキュア #ふたり_はぐ\r?\n/, result)
    end

    # 正規化すると空になる値 (記号だけ) は落とす。`#` だけの裸のタグを出さない。
    def test_symbol_only_tags_are_dropped
      assert_no_match(/DESCRIPTION/, ics(described(extra_tags: ['！？', '＃'])))
      assert_match(
        /DESCRIPTION:#プリキュア\r?\n/,
        ics(described(extra_tags: ['！？', 'プリキュア'])),
      )
    end

    # 説明があれば置き換える。注意書きをタグに埋もれさせない。
    def test_description_replaces_hashtags
      result = ics(described(description: '本日は特番のため 30 分繰り下げ', extra_tags: ['プリキュア']))

      assert_match(/DESCRIPTION:本日は特番のため 30 分繰り下げ/, result)
      assert_no_match(/#プリキュア/, result)
    end

    # どちらも無ければ DESCRIPTION 自体を出さない。空の本文を送らない。
    def test_description_is_omitted_when_empty
      assert_no_match(/DESCRIPTION/, ics(described))
      assert_no_match(/DESCRIPTION/, ics(described(description: '   ')))
      assert_no_match(/DESCRIPTION/, ics(described(extra_tags: [])))
      assert_no_match(/DESCRIPTION/, ics(described(extra_tags: ['', '  '])))
    end

    # 文字列でない値 (YAML 手編集) で落ちない。
    def test_non_string_description_is_ignored
      assert_no_match(/DESCRIPTION/, ics(described(description: 12_345)))
      assert_no_match(/DESCRIPTION/, ics(described(extra_tags: 'プリキュア')))
    end

    # RFC 5545 のエスケープは icalendar gem に任せている。改行とカンマが
    # 素通しされると購読側のパースが壊れるので、任せきりでよいことを確かめる。
    def test_description_escapes_newline_and_comma
      result = ics(described(description: "1 行目,カンマ\n2 行目"))

      assert_match(/DESCRIPTION:1 行目\\,カンマ\\n2 行目/, result)
    end

    # VEVENT の順序は購読側の挙動に影響しないが、他の面と揃える (#4540)。
    def test_events_are_ordered_by_next_on_then_start_time
      data = {
        'daily' => {'series' => '毎日', 'start_time' => '23:00', 'enable' => true},
        'later' => {
          'series' => '後', 'next_on' => '2026-06-02', 'start_time' => '20:00', 'enable' => true
        },
        'sooner_late' => {
          'series' => '先の遅い枠', 'next_on' => '2026-06-01', 'start_time' => '21:00', 'enable' => true
        },
        'sooner_early' => {
          'series' => '先の早い枠', 'next_on' => '2026-06-01', 'start_time' => '19:00', 'enable' => true
        },
      }
      order = ics(data).scan(/UID:program-(\w+)@mulukhiya/).flatten

      assert_equal(['sooner_early', 'sooner_late', 'later', 'daily'], order)
    end
  end
end
