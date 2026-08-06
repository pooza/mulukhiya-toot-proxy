require 'icalendar'

module Mulukhiya
  # 番組表 (Program) を iCalendar (.ics) へ変換する。tomato-shrieker の
  # IcalendarSource から購読され、放送開始通知に使われる (#4287)。
  #
  # 出力は常に「次回発生 1 件」の VEVENT で、**RRULE は付けない**。話数は動的値で
  # 未来分が確定しないため、先々まで繰り返しイベントを出しても中身を埋められない。
  # 用途は tomato-shrieker への直前/開始通知に限定で、Google カレンダー等への購読
  # リマインダーは非対応 (取得ラグ + 話数を載せられない)。
  #
  # 次回がいつかは `next_on` (次回放送日) で決まる (#4373)。
  #
  #   next_on 未設定 → 毎日扱い。今日 (放送中なら今日) か明日の start_time
  #   next_on あり   → その日の start_time に 1 件だけ。**過ぎたら出力しない**
  #   next_on 不正   → **出力しない**。毎日扱いへ倒すと古い話数で毎日鳴る
  #
  # ⚠ 曜日ルール (frequency + weekday) は採らなかった。ズレを検出できないうえ
  # fail-open で、**古い話数のまま毎週誤発火する**。価値が話数である以上、
  # 間違った話数で鳴るのは鳴らないより悪い。next_on は fail-closed で黙る
  # (気づけるよう番組表エディタが過去日に警告を出す)。
  class ProgramCalendar
    include Package

    PRODID = '-//mulukhiya//program//JA'.freeze
    DEFAULT_DURATION_MINUTES = 30
    # Asia/Tokyo は DST が無く常に +09:00。VTIMEZONE を埋め込まず、
    # DTSTART/DTEND は UTC (末尾 Z) で出力して曖昧さを排除する。
    TZ_OFFSET = '+09:00'.freeze

    def initialize(data = nil, now: Time.now)
      @data = data || Program.instance.data
      @now = now
    end

    def to_ics
      cal = Icalendar::Calendar.new
      cal.prodid = PRODID
      entries.each do |key, entry|
        event = build_event(key, entry)
        cal.add_event(event) if event
      end
      cal.publish
      return cal.to_ical
    end

    private

    # 有効 (enable) かつ妥当な start_time を持つエントリのみ。
    # air (エア番組) は抽出条件に含めない。
    def entries
      return @data.select do |_key, entry|
        entry.is_a?(Hash) &&
            entry['enable'] == true &&
            valid_start_time?(entry['start_time'])
      end
    end

    def valid_start_time?(value)
      return value.is_a?(String) && ProgramEntryContract::TIME_FORMAT.match?(value)
    end

    # 次回発生が無い (next_on を過ぎた) エントリは nil を返し、出力しない。
    def build_event(key, entry)
      minutes = duration_minutes(entry)
      start = next_occurrence(entry, minutes)
      return nil unless start
      event = Icalendar::Event.new
      event.uid = "program-#{key}@mulukhiya"
      event.dtstamp = utc_value(@now)
      event.dtstart = utc_value(start)
      event.dtend = utc_value(start + (minutes * 60))
      event.summary = summary(entry)
      return event
    end

    # UTC 値として出力させ、末尾 Z を付与する (tzid: 'UTC' 指定が必要)。
    def utc_value(time)
      return Icalendar::Values::DateTime.new(time.utc, 'tzid' => 'UTC')
    end

    def duration_minutes(entry)
      minutes = entry['minutes']
      return minutes.is_a?(Integer) && minutes.positive? ? minutes : DEFAULT_DURATION_MINUTES
    end

    # 次回発生時刻 (JST)。無ければ nil。
    #
    # 放送中 (開始済みかつ終了前) は当日のイベントを残し、終了時刻
    # (start + duration) を過ぎて初めて次へ送る。これにより放送開始分ちょうどに
    # 取得しても当日イベントが欠落せず、start_time 通知の取り逃しを防ぐ (#4287)。
    def next_occurrence(entry, duration_minutes)
      now_jst = @now.getlocal(TZ_OFFSET)
      hour, minute = entry['start_time'].split(':').map(&:to_i)
      if entry['next_on'].present?
        # ⚠ 値がある以上、解釈できなければ毎日扱いへ倒さず黙る (fail-closed)。
        # 倒すと「日付を間違えた」が「古い話数で毎日鳴る」に化ける。曜日ルールを
        # 却下した理由 (冒頭コメント) が、そのまま不正値の経路にも効く。
        date = scheduled_date(entry)
        return nil unless date
        # next_on 指定あり: その日に 1 回だけ。終了済みなら翌日へ送らず消す。
        candidate = Time.new(date.year, date.month, date.day, hour, minute, 0, TZ_OFFSET)
        return nil if (candidate + (duration_minutes * 60)) <= now_jst
        return candidate
      end
      candidate = Time.new(now_jst.year, now_jst.month, now_jst.day, hour, minute, 0, TZ_OFFSET)
      candidate += 86_400 if (candidate + (duration_minutes * 60)) <= now_jst
      return candidate
    end

    # next_on を Date で返す。不正値は nil (呼び出し側がイベントごと落とす)。
    # 不正値で番組表全体を落とさない。
    #
    # ⚠ Date.strptime は寛容で `2026-08-08junk` や `2026-8-8` を通す。書式は
    # contract と同じ判定で先に見る (Codex P2 / PR #4529)。
    def scheduled_date(entry)
      value = entry['next_on']
      # YAML の手編集で `next_on: 20260808` と書くと Integer で入る。
      unless value.is_a?(String) && ProgramEntryContract.valid_date?(value)
        logger.error(message: 'program next_on invalid', next_on: value)
        return nil
      end
      return Date.strptime(value, '%Y-%m-%d')
    end

    def summary(entry)
      parts = [entry['series']]
      parts << "#{entry['episode']}#{entry['episode_suffix'] || '話'}" if entry['episode']
      parts << entry['subtitle'] if entry['subtitle']
      return parts.compact.join(' ')
    end
  end
end
