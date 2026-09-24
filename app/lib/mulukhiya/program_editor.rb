module Mulukhiya
  # 番組表の編集 (書き込み) を担う (#4570)。
  #
  # `Program` は参照とデータ表現に絞り、書き込みの直列化 (#4534)・値の正規化・
  # Annict の解決はこちらが持つ。⚠ **番組表への書き込み経路はここだけ**にする。
  # `ProgramFetcher#save` を直に呼ぶ道を別に作ると、#4534 で塞いだ lost update が
  # そのまま復活する。
  #
  # ⚠ `Program` と違って `Singleton` ではない。ロックの実体は Redis 側にあるので、
  # インスタンスが複数あっても同じ key を取り合って直列化される。
  class ProgramEditor
    include Package

    # 「日付 ＋」ボタンが next_on を進める既定日数 (#4585)。
    #
    # ⚠ **週次前提の 7 日は捨てた。**翌日放送であることがあり、週次では表現できない。
    # +1 日なら 7 回押して翌週も兼ねられるので、粒度の細かいほうへ寄せる。
    # ⚠ **7 を別名で残さないこと**（週次前提が別の場所へ生き延びる）。
    NEXT_ON_ADVANCE_DEFAULT_DAYS = 1

    # 1 リクエストで進められる日数の上限 (#4585)。UI は連打を 1 リクエストへ畳んで
    # 送る（#4534 のロック取得回数を増やさないため）ので、桁を間違えた値で年単位に
    # 飛ばないよう歯止めを置く。
    NEXT_ON_ADVANCE_MAX_DAYS = 366

    # ⚠ 既定を `Program.instance` の評価にしているのは呼び出し時。クラスの読み込み
    # 順に依存させない。
    def initialize(program = Program.instance)
      @program = program
    end

    # 番組表全体の差し替え。auto_update の pull（ProgramUpdateWorker）と rake から
    # `Program#save` 経由で呼ばれる。編集メソッドと同じロックで直列化する (#4534)。
    #
    # ⚠ 編集メソッドは lock.synchronize の内側で fetcher.save を直接呼ぶ。
    # ここを経由させると自分自身のロックと衝突して ConflictError になる。
    # 逆に、ロックの外から fetcher.save を呼ぶと #4534 で塞いだ lost update が
    # そのまま復活する。
    def save(programs)
      return lock.synchronize {fetcher.save(programs)}
    end

    def add_entry(key, attributes)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      raise Ginseng::ValidateError, 'キーが空です。' if key.empty?
      return lock.synchronize do
        programs = data
        raise ConflictError.new("キー '#{key}' は既に存在します。", code: :duplicate_key) if programs.key?(key)
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
    # ⚠ 代わりに「引いた時点の話数と作品 ID」を持ち回り、**ロックの中で両方とも
    # 一致したときだけ載せる**。一致しない = 待っている間に別の +1 が入ったか作品を
    # 差し替えられた、ということなので、古い内容で上書きしてはいけない。載せなかった
    # 場合は annict_episode_id が nil のまま（Annict が引けなかったときと同じ状態）。
    def increment_episode(key, annict: nil)
      return increment_episode_with_annict(key, annict:)[:entry]
    end

    # increment_episode と同じ。Annict のメタデータを載せたか・載せなかった理由も返す (#4579)。
    #
    # - `applied` — 載せた
    # - `unconfigured` — Annict 未連携か、作品 ID が紐づいていない
    # - `not_found` — 該当話数が Annict に無い
    # - `failed` — Annict の呼び出しが失敗した
    # - `superseded` — 引いている間に別の編集が入ったので載せなかった
    #
    # ⚠⚠ **どれでも話数の +1 は成功して保存されている。**`applied` 以外でも
    # increment を送り直してはいけない（話数が飛ぶ）。足りないのは
    # `annict_episode_id` と `subtitle` だけ。
    def increment_episode_with_annict(key, annict: nil)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      prepared = prepare_annict_increment(key, annict)
      return lock.synchronize do
        programs = data
        raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
        entry = programs[key]
        entry['episode'] = (entry['episode'] || 0).to_i + 1
        state = apply_annict_increment(key, prepared, entry)
        fetcher.save(programs)
        next {entry:, annict: state}
      end
    end

    # next_on だけを進める (#4585)。話数・サブタイトルには触らない。
    #
    # 「次回」ボタンが話数と日付を同時に動かしていたのをやめ、独立した操作にした。
    # 話数だけ直したいときに日付が巻き込まれず、⚠ **Annict が載らずに 200 が
    # 返ったときの巻き戻し量も半分になる**（#4585）。
    #
    # ⚠ 書き込みは #4534 のロックの内側で行う。ここを `save` 経由にすると自分の
    # ロックと衝突して 409 になるので、`fetcher.save` を直接呼ぶ。
    def advance_next_on(key, days: NEXT_ON_ADVANCE_DEFAULT_DAYS)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      days = coerce_advance_days(days)
      return lock.synchronize do
        programs = data
        raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
        entry = programs[key]
        shift_next_on(entry, days)
        fetcher.save(programs)
        next entry
      end
    end

    private

    # 読みは `Program` 側の正本を使う。⚠ **ここで独自に load しない。**
    # coerce_scalars を通っていないデータで read-modify-write すると、YAML の
    # 手書き由来の型ゆれ（#4373 / #4537）をそのまま書き戻すことになる。
    def data
      return @program.data
    end

    def auto_update?
      return @program.auto_update?
    end

    # ⚠ `Program` とは別インスタンスだが、`ProgramFetcher` はプロセス内に状態を
    # 持たない（キャッシュの実体は Redis、`cached_data` は毎回引く）ので、読み書きが
    # 食い違うことはない。
    def fetcher
      @fetcher ||= ProgramFetcher.new
    end

    # 書き込みの直列化ロック (#4534)。⚠ ロックの実体は Redis 側にあるので、
    # インスタンスやプロセスをまたいでも効く。
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

    # next_on を days 日進める (#4585)。
    #
    # ⚠ next_on を持たないエントリ (= 毎日枠) には触らない。日付を勝手に生やすと
    # 翌日以降そのエントリが単発扱いになり、毎日出ていたイベントが消える。
    # WebUI も同じ判定でボタンを出さないが、正本はこちら。
    #
    # ⚠ 書式は contract と同じ判定で見る。Date.strptime は `2026-08-08junk` を
    # 通すので、素で渡すと壊れた値を黙って別の壊れた値へ書き換える
    # (Codex P2 / PR #4529)。
    def shift_next_on(entry, days)
      return entry['next_on'] unless entry['next_on'].is_a?(String) && entry['next_on'].present?
      unless ProgramEntryContract.valid_date?(entry['next_on'])
        # 不正値は触らずそのまま残す。壊れた値を別の壊れた値へ書き換えない。
        logger.error(message: 'program next_on invalid', next_on: entry['next_on'])
        return entry['next_on']
      end
      entry['next_on'] = (Date.strptime(entry['next_on'], '%Y-%m-%d') + days)
        .strftime('%Y-%m-%d')
      return entry['next_on']
    end

    # 進める日数を検証して Integer にする。未指定は既定 (1 日)。
    #
    # ⚠ 素の to_i に倒さない。`'abc'.to_i` は 0 なので、壊れた値が「何も起きない
    # 成功」に化けて、押したのに進まない理由が誰にも分からなくなる。
    def coerce_advance_days(days)
      return NEXT_ON_ADVANCE_DEFAULT_DAYS if days.nil? || days.to_s.strip.empty?
      value = Integer(days.to_s, 10, exception: false)
      return value if value && (1..NEXT_ON_ADVANCE_MAX_DAYS).cover?(value)
      raise Ginseng::ValidateError,
        "日数は 1〜#{NEXT_ON_ADVANCE_MAX_DAYS} の整数で指定してください。"
    end

    # auto_update 有効時は外部 (GAS 等) が番組表データの正本。エディタからの
    # 書き込みは次の pull で上書き消失するので、書き込み API 自体を 409 で
    # 拒否し「auto_update を切ってから編集する」運用に倒す (#4272)。
    def auto_update_conflict
      return ConflictError.new('自動更新が有効のため、編集できません。', code: :auto_update)
    end

    # ロックを取る前に Annict を引く。annict が無い / 作品 ID が紐づいていない
    # エントリではネットワークへ出ない。
    #
    # ⚠ ここでの読みは Annict を先に引くためだけのもの。**存在チェックの正本は
    # ロックの中**（外で raise すると、ロック競合より先に 404 を返してしまう）。
    def prepare_annict_increment(key, annict)
      current = data[key] || {}
      episode = (current['episode'] || 0).to_i + 1
      work_id = current['annict_work_id']
      return {episode:, work_id:, state: :unconfigured} unless annict && work_id
      begin
        episode_data = next_annict_episode(annict, work_id, episode)
      rescue => e
        e.alert
        return {episode:, work_id:, state: :failed}
      end
      return {episode:, work_id:, episode_data:, state: episode_data ? nil : :not_found}
    end

    # ロックの外で引いた Annict の結果を、ロックの中で確定した話数に載せてよいか。
    #
    # ⚠ 待っている間に別の +1 が入っていたら**載せない**。載せると古い話数の
    # サブタイトル・annict_episode_id で新しい話数を上書きしてしまう（#4534 で
    # 塞いだ lost update と同じ壊れ方を、別経路で作ることになる）。
    #
    # ⚠ **話数だけでなく作品 ID も見る** (PR #4571 の Codex P2)。
    # ProgramEntryUpdateContract は annict_work_id の変更を許しているので、
    # 待っている間に作品を差し替えられると「話数は同じだが別作品」になる。
    # そこへ旧作品のサブタイトルを載せてはいけない。
    #
    # 載せなかった場合は annict_episode_id が nil のまま = Annict を引けなかった
    # ときと同じ状態になる。
    def annict_applicable?(prepared, entry)
      return false unless prepared[:episode_data]
      return prepared.values_at(:episode, :work_id) == entry.values_at('episode', 'annict_work_id')
    end

    # ロックの中で確定したエントリへ、ロックの外で引いた Annict の結果を載せる。
    #
    # ⚠ **`annict_episode_id` は先に必ず nil へ落とす。**載せない回に前回の値が
    # 残ると、新しい話数に古い Annict の ID が付いたままになる。
    #
    # 戻り値は increment_episode_with_annict の `annict`。
    def apply_annict_increment(key, prepared, entry)
      entry['annict_episode_id'] = nil
      # `episode_data` が無い回は「Annict を引けなかった」であって、ガードの発動ではない。
      return prepared[:state] unless prepared[:episode_data]
      unless annict_applicable?(prepared, entry)
        log_annict_stale(key, prepared, entry)
        return :superseded
      end
      entry['annict_episode_id'] = prepared[:episode_data]['annictId']
      entry['subtitle'] = prepared[:episode_data]['title'] if prepared[:episode_data]['title']
      return :applied
    end

    # ガードが実際に効いたことを残す (#4577 の 3)。
    #
    # ⚠⚠ **載せなかった結果は `annict_episode_id: nil` ＝「Annict を引けなかった」
    # ときと同じ状態**なので、ログが無いと両者を区別する手段がゼロになる。
    # 運用者から見ると、どちらも「次話を押して 200 が返り、サブタイトルだけ
    # 入らない」という同じ見え方をする。**これは #4534 のガードが意図どおり
    # 働いたことを示す唯一の観測点**になる。
    #
    # ⚠⚠ **「押し直すべきか」の材料ではない。答えは「押し直してはいけない」で
    # 確定している。**`increment_episode` は話数の +1・`next_on` の前進・`save` を
    # この判定より**前に無条件で**済ませているので、増分そのものは成功している。
    # 押し直すと話数を飛ばして日付が 7 日ずれる。
    #
    # ⚠ **期待値と実値の両方を出す。**Annict 側の障害なのか、待っている間に
    # 別の編集が入ってガードが正しく働いたのかで、運用者が
    # 「`PUT` でメタデータを補う」のか「Annict の設定を見る」のかが変わる。
    #
    # ⚠ **`prepared[:episode_data]` が無い回はここへ来ない。**あれは Annict を
    # 引けなかった（または作品が紐づいていない）回で、ガードの発動ではない。
    #
    # ⚠ `alert` ではなく `info`。⚠⚠ **ガードが働くのは正常な動作**なので、
    # 上げると「クライアント起因なのに alert」（#4542 / #4534 で外してきた形）に戻る。
    def log_annict_stale(key, prepared, entry)
      logger.info(program_entry: {
        event: 'annict_stale',
        key: key,
        prepared_episode: prepared[:episode],
        actual_episode: entry['episode'],
        prepared_work_id: prepared[:work_id],
        actual_work_id: entry['annict_work_id'],
      })
    end

    # ⚠ 失敗は握らない。呼び出し元が `failed` と `not_found` を分けるため (#4579)。
    def next_annict_episode(annict, work_id, episode_number)
      episodes = annict.episodes([work_id.to_i]) || []
      target = episode_number.to_i
      return episodes.find do |ep|
        match = ep['numberText'].to_s.match(/(\d+)/)
        match && match[1].to_i == target
      end
    end
  end
end
