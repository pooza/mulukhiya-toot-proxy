module Mulukhiya
  # 番組表データの参照 (ドメインロジック) を担う。HTTP 取得・YAML/Redis
  # 永続化といった I/O は ProgramFetcher へ、編集は ProgramEditor へ委譲する
  # (#4347 / #4570)。
  #
  # ⚠ **編集系をここへ戻さないこと。**参照系と編集系の 2 つを抱えていたのが
  # ClassLength を超えた原因で、#4534 で persist を潰したのは設計判断ではなく
  # 上限合わせだった（#4570）。書き込みが要るなら ProgramEditor に足す。
  class Program
    include Singleton
    include Package

    # 後方互換: rake task / テストが参照するため委譲先の定数を再公開する。
    YAML_PATH = ProgramFetcher::YAML_PATH

    def update
      return nil unless auto_update?
      programs = fetcher.fetch
      return nil unless programs
      return save(programs)
    end

    def auto_update?
      return config['/program/auto_update'] != false
    end

    # 番組表全体の差し替え。auto_update の pull（ProgramUpdateWorker）と rake から
    # 呼ばれる。⚠ **書き込みの直列化 (#4534) は ProgramEditor が持つ**ので、
    # ここは素通しにせず必ずエディタを経由する。
    def save(programs)
      return editor.save(programs)
    end

    # 編集の入口 (#4570)。⚠ **番組表への書き込みはここから先だけ**。
    def editor
      @editor ||= ProgramEditor.new(self)
    end

    def data
      return fetcher.load.each_with_object({}) do |(key, entry), result|
        next unless entry.is_a?(Hash)
        result[key] = coerce_scalars(entry).merge('extra_tags' => entry['extra_tags'] || [])
      end
    end

    # 放送順に並べた番組表 (#4540)。外部へ出す面 (API・iCalendar・エディタ) は
    # これを使う。
    #
    # ⚠ data 自体は並べ替えない。data は編集の read-modify-write にも使われる
    # ので、ここで並べると var/program.yaml の行順まで書き換わる。
    def sorted_data
      return data.sort_by {|key, entry| self.class.sort_key(key, entry)}.to_h
    end

    # 番組表の標準の並び順 = next_on 昇順 → start_time 昇順 (#4540)。
    #
    # next_on は YYYY-MM-DD 固定なので字句比較でそのまま日付順になる。日付を
    # 持たない「毎日」枠は次回がいつか決まらないので末尾へ送る。手編集で入った
    # 不正値 (`20260808` 等) は「値がある」側として日付群の直後に寄るが、
    # エディタが警告バッジを出す位置には残るのでこれでよい。
    #
    # 同値のときはキーで決める。並びが実行のたびに揺れると差分が読めなくなる。
    def self.sort_key(key, entry)
      return [
        entry['next_on'].present? ? 0 : 1,
        entry['next_on'].to_s,
        start_minutes(entry['start_time']),
        key.to_s,
      ]
    end

    # 開始時刻を 0 時からの分に直す。HH:MM として読めない値 (未設定、手編集で
    # 入った Integer 等) はその日の末尾へ送る。
    def self.start_minutes(value)
      return Float::INFINITY unless value.is_a?(String)
      return Float::INFINITY unless ProgramEntryContract::TIME_FORMAT.match?(value)
      hour, minute = value.split(':').map(&:to_i)
      return (hour * 60) + minute
    end

    def count
      return data.count
    end

    def to_yaml
      return data.to_yaml
    end

    def uris
      return fetcher.uris
    end

    def yaml_exist?
      return fetcher.yaml_exist?
    end

    def invalidate_cache
      return fetcher.invalidate_cache
    end

    alias to_s to_yaml

    private

    def fetcher
      @fetcher ||= ProgramFetcher.new
    end

    # ⚠ YAML を手書きすると、クォートを付け忘れたスカラーが意図しない型で入る。
    # 読み込み時にここで文字列へ寄せ、以降の層は常に文字列だけを見ればよくする
    # (#4373)。エディタ経由の書き込みは to_yaml がクォートするので無害。
    #
    #   next_on: 2026-08-08          → Date（許可しないと番組表全体が読めない）
    #   next_on: 2026-08-08 09:00:00 → Time（同上・#4537）
    #   start_time: 20:30            → 73800（YAML の 60 進数解釈）
    def coerce_scalars(entry)
      coerced = entry.dup
      coerced['next_on'] = format_date(coerced['next_on'])
      coerced['start_time'] = format_sexagesimal(coerced['start_time']) if
        sexagesimal_time?(coerced['start_time'])
      return coerced
    end

    # next_on を 'YYYY-MM-DD' へ寄せる。日付として読めない値 (String・Integer 等)
    # はそのまま返し、妥当性の判定は contract / ProgramCalendar に任せる。
    #
    # ⚠ Time はゾーンを付けずに書くと Psych が **UTC として** 読み、ローカル
    # (JST) へ変換された Time が返る。そのまま strftime すると
    # `2026-08-08 23:30:00` が 2026-08-09 になってしまうので、UTC 側で日付を採る
    # = 書いたとおりの日付を拾う (#4537)。
    #
    # ⚠ **YAML の next_on はここへ来る前に String へ正規化されている**
    # (`ProgramFetcher#parse_yaml`・#4558)。ここでの `getutc` は最後の保険で、
    # **明示オフセット付きの Time には日付が 1 日ずれる**（materialize 済みの
    # Time からはゾーンレスと区別できない）。next_on の読み方を直すときは
    # この層ではなく parse_yaml を触ること。
    def format_date(value)
      return value.strftime('%Y-%m-%d') if value.is_a?(Date) # DateTime も含む
      return value.getutc.strftime('%Y-%m-%d') if value.is_a?(Time)
      return value
    end

    # ⚠ ただの整数 (`start_time: 20`) は 60 進数ではない。'00:00' へ寄せると
    # 深夜 0 時のイベントとして出てしまうので、Integer のまま残して
    # valid_start_time? に弾かせる (Codex P2 / PR #4529)。
    def sexagesimal_time?(value)
      return false unless value.is_a?(Integer)
      return false unless (0...86_400).cover?(value)
      return (value % 60).zero?
    end

    # YAML が 60 進数として読んだ 20:30 (= 73800) を 'HH:MM' へ戻す。
    def format_sexagesimal(value)
      return '%02d:%02d' % [value / 3600, (value % 3600) / 60]
    end
  end
end
