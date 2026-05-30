require 'icalendar'

module Mulukhiya
  # 番組表 (Program) を iCalendar (.ics) へ変換する。tomato-shrieker の
  # IcalendarSource から購読され、放送開始通知に使われる (#4287)。
  #
  # 現状エントリは放送曜日を持たないため、繰り返し (RRULE) は付けず、
  # start_time の「次回発生」を 1 件の VEVENT として出力する MVP 実装。
  # 曜日欄が追加されれば週次 RRULE へ拡張できる。
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
      entries.each {|key, entry| cal.add_event(build_event(key, entry))}
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

    def build_event(key, entry)
      minutes = duration_minutes(entry)
      start = next_occurrence(entry['start_time'], minutes)
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

    # start_time (HH:MM, JST) の「次に訪れる時刻」を返す。放送中 (開始済みかつ
    # 終了前) は今日のイベントを残し、終了時刻 (start + duration) を過ぎて初めて
    # 翌日へ送る。これにより放送開始分ちょうどに取得しても当日イベントが欠落せず、
    # start_time 通知の取り逃しを防ぐ (#4287)。
    def next_occurrence(start_time, duration_minutes)
      hour, minute = start_time.split(':').map(&:to_i)
      now_jst = @now.getlocal(TZ_OFFSET)
      candidate = Time.new(now_jst.year, now_jst.month, now_jst.day, hour, minute, 0, TZ_OFFSET)
      candidate += 86_400 if (candidate + (duration_minutes * 60)) <= now_jst
      return candidate
    end

    def summary(entry)
      parts = [entry['series']]
      parts << "#{entry['episode']}#{entry['episode_suffix'] || '話'}" if entry['episode']
      parts << entry['subtitle'] if entry['subtitle']
      return parts.compact.join(' ')
    end
  end
end
