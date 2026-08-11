module Mulukhiya
  # 番組表データの参照・編集 (ドメインロジック) を担う。HTTP 取得・YAML/Redis
  # 永続化といった I/O は ProgramFetcher へ委譲する (#4347)。
  class Program
    include Singleton
    include Package

    # 後方互換: rake task / テストが参照するため委譲先の定数を再公開する。
    YAML_PATH = ProgramFetcher::YAML_PATH

    # 「次回」ボタンが next_on を進める日数 (#4373)。durable な対象がウィークリー
    # 枠だけなので固定でよい。他の周期が要るようになったら、規則を持たせるのでは
    # なく日付を直接編集する運用で足りるか先に確かめること。
    NEXT_ON_INTERVAL_DAYS = 7

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
    # 呼ばれる。エディタ経由の書き込みと同じロックで直列化する (#4534)。
    #
    # ⚠ 編集 4 メソッドは lock.synchronize の内側で fetcher.save を直接呼ぶ。
    # ここを経由させると自分自身のロックと衝突して ConflictError になる。
    # 逆に、ロックの外から fetcher.save を呼ぶと #4534 で塞いだ lost update が
    # そのまま復活する。
    def save(programs)
      return lock.synchronize {fetcher.save(programs)}
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

    def add_entry(key, attributes)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      raise Ginseng::ValidateError, 'キーが空です。' if key.empty?
      return lock.synchronize do
        programs = data
        raise Ginseng::ConflictError, "キー '#{key}' は既に存在します。" if programs.key?(key)
        attrs = attributes.transform_keys(&:to_s).reject {|_, v| blank_value?(v)}
        programs[key] = attrs.to_h {|k, v| [k, normalize_value(k, v)]}
        fetcher.save(programs)
        next programs[key]
      end
    end

    def generate_key(attributes = {})
      programs = data
      loop do
        base = [
          Environment.domain_name,
          attributes[:series] || attributes['series'],
          attributes[:episode] || attributes['episode'],
          Time.now.to_f,
          SecureRandom.hex(4),
        ].join('|')
        key = Digest::SHA256.hexdigest(base)[0, 12]
        return key unless programs.key?(key)
      end
    end

    def update_entry(key, attributes)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      return lock.synchronize do
        programs = data
        raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
        attributes.each do |k, v|
          if blank_value?(v)
            programs[key].delete(k.to_s)
          else
            programs[key][k.to_s] = normalize_value(k.to_s, v)
          end
        end
        fetcher.save(programs)
        next programs[key]
      end
    end

    def delete_entry(key)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      return lock.synchronize do
        programs = data
        next nil unless programs.key?(key)
        entry = programs.delete(key)
        fetcher.save(programs)
        next entry
      end
    end

    # ⚠ Annict の GraphQL 呼び出しは**ロックの外**で先に済ませる (#4534)。
    #
    # 当初はロックの内側に置いていたが、それだと **TTL を超えうる**（open と read で
    # 各 5 秒 × 最大 3 回 + リトライ待ち ≧ 30 秒）。ロックが先に失効すると別の編集が
    # 獲得でき、そこへ元のリクエストが書き戻して**塞いだはずの lost update が
    # そのまま戻る**（PR #4569 の Codex P2）。TTL を伸ばす手もあるが、プロセスが
    # 死んだときに編集が止まる時間もそのまま伸びるので採らない。
    #
    # ⚠ 代わりに「引いた時点の話数」を持ち回り、**ロックの中で話数が一致したときだけ
    # 載せる**。一致しない = 待っている間に別の +1 が入った、ということなので、
    # 古い話数のサブタイトルで上書きしてはいけない。載せなかった場合は
    # annict_episode_id が nil のまま（Annict が引けなかったときと同じ状態）になる。
    def increment_episode(key, annict: nil)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      next_episode, next_ep = prepare_annict_increment(key, annict)
      return lock.synchronize do
        programs = data
        raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
        entry = programs[key]
        entry['episode'] = (entry['episode'] || 0).to_i + 1
        entry['annict_episode_id'] = nil
        advance_next_on(entry)
        if annict_applicable?(next_ep, next_episode, entry['episode'])
          entry['annict_episode_id'] = next_ep['annictId']
          entry['subtitle'] = next_ep['title'] if next_ep['title']
        end
        fetcher.save(programs)
        next entry
      end
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

    # 書き込みの直列化ロック (#4534)。⚠ Program は Singleton なので、この
    # インスタンスはプロセス内で共有される。ロックの実体は Redis 側なので
    # プロセスをまたいでも効く。
    def lock
      @lock ||= ProgramLockStorage.new
    end

    # nil または空白のみの文字列は「未設定」として扱い、保存対象から除く。
    # contract で start_time: "" を許容している (#4366) ため、空文字が
    # machine-readable な start_time 欄にそのまま永続化されるのを防ぐ。
    # 空配列 (extra_tags のクリア) は正当値なので String のみ対象とする。
    def blank_value?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    # start_time は 24 時間制 HH:MM。contract は時の先頭ゼロ省略 (例 9:00) を
    # 許容するため、保存時に 2 桁ゼロ埋め (09:00) へ正規化し、表示・データの
    # ゆれをなくす (#4372)。contract 検証後に呼ばれる前提で、想定外の値は
    # 触らず素通しする。
    def normalize_value(key, value)
      return value.strftime('%Y-%m-%d') if key.to_s == 'next_on' && value.is_a?(Date)
      return value unless key.to_s == 'start_time' && value.is_a?(String)
      hour, minute = value.split(':', 2)
      return value unless minute && hour.match?(/\A\d{1,2}\z/)
      return '%02d:%s' % [hour.to_i, minute]
    end

    # 「次回」ボタンで話数を進めるとき、next_on を持つエントリは放送日も 1 週
    # 進める (#4373)。ウィークリー枠の日付更新を既存の操作へ相乗りさせ、
    # 「毎週日付を打ち直す」手間を作らないための措置。
    #
    # ⚠ next_on を持たないエントリ (= 毎日枠) には触らない。日付を勝手に生やすと
    # 翌日以降そのエントリが単発扱いになり、毎日出ていたイベントが消える。
    #
    # ズレたら日付を直接編集する。ここは既定値の前進であって規則ではない。
    #
    # ⚠ 書式は contract と同じ判定で見る。Date.strptime は `2026-08-08junk` を
    # 通すので、素で渡すと壊れた値を黙って別の壊れた値へ書き換える
    # (Codex P2 / PR #4529)。
    def advance_next_on(entry)
      return entry['next_on'] unless entry['next_on'].is_a?(String) && entry['next_on'].present?
      unless ProgramEntryContract.valid_date?(entry['next_on'])
        # 不正値は触らずそのまま残す。話数の +1 まで巻き添えで落とさない。
        logger.error(message: 'program next_on invalid', next_on: entry['next_on'])
        return entry['next_on']
      end
      entry['next_on'] = (Date.strptime(entry['next_on'], '%Y-%m-%d') + NEXT_ON_INTERVAL_DAYS)
        .strftime('%Y-%m-%d')
      return entry['next_on']
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

    # auto_update 有効時は外部 (GAS 等) が番組表データの正本。エディタからの
    # 書き込みは次の pull で上書き消失するので、書き込み API 自体を 409 で
    # 拒否し「auto_update を切ってから編集する」運用に倒す (#4272)。
    def auto_update_conflict
      return Ginseng::ConflictError.new('自動更新が有効のため、編集できません。')
    end

    # ロックを取る前に Annict を引く。annict が無い / 作品 ID が紐づいていない
    # エントリではネットワークへ出ない。
    #
    # ⚠ ここでの読みは Annict を先に引くためだけのもの。**存在チェックの正本は
    # ロックの中**（外で raise すると、ロック競合より先に 404 を返してしまう）。
    def prepare_annict_increment(key, annict)
      current = data[key] || {}
      episode = (current['episode'] || 0).to_i + 1
      return [episode, nil] unless annict && current['annict_work_id']
      return [episode, next_annict_episode(annict, current['annict_work_id'], episode)]
    end

    # ロックの外で引いた Annict の結果を、ロックの中で確定した話数に載せてよいか。
    #
    # ⚠ 待っている間に別の +1 が入っていたら**載せない**。載せると古い話数の
    # サブタイトル・annict_episode_id で新しい話数を上書きしてしまう（#4534 で
    # 塞いだ lost update と同じ壊れ方を、別経路で作ることになる）。
    # 載せなかった場合は annict_episode_id が nil のまま = Annict を引けなかった
    # ときと同じ状態になる。
    def annict_applicable?(next_ep, expected_episode, actual_episode)
      return false unless next_ep
      return expected_episode == actual_episode
    end

    def next_annict_episode(annict, work_id, episode_number)
      episodes = annict.episodes([work_id.to_i]) || []
      target = episode_number.to_i
      return episodes.find do |ep|
        match = ep['numberText'].to_s.match(/(\d+)/)
        match && match[1].to_i == target
      end
    rescue => e
      e.alert
      return nil
    end
  end
end
