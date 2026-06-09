module Mulukhiya
  # 番組表データの参照・編集 (ドメインロジック) を担う。HTTP 取得・YAML/Redis
  # 永続化といった I/O は ProgramFetcher へ委譲する (#4347)。
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

    def save(programs)
      return fetcher.save(programs)
    end

    def data
      return fetcher.load.each_with_object({}) do |(key, entry), result|
        next unless entry.is_a?(Hash)
        result[key] = entry.merge('extra_tags' => entry['extra_tags'] || [])
      end
    end

    def add_entry(key, attributes)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      raise Ginseng::ValidateError, 'キーが空です。' if key.empty?
      programs = data
      raise Ginseng::ConflictError, "キー '#{key}' は既に存在します。" if programs.key?(key)
      attrs = attributes.transform_keys(&:to_s).reject {|_, v| blank_value?(v)}
      programs[key] = attrs.to_h {|k, v| [k, normalize_value(k, v)]}
      save(programs)
      return programs[key]
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
      programs = data
      raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
      attributes.each do |k, v|
        if blank_value?(v)
          programs[key].delete(k.to_s)
        else
          programs[key][k.to_s] = normalize_value(k.to_s, v)
        end
      end
      save(programs)
      return programs[key]
    end

    def delete_entry(key)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      programs = data
      return nil unless programs.key?(key)
      entry = programs.delete(key)
      save(programs)
      return entry
    end

    def increment_episode(key, annict: nil)
      raise auto_update_conflict if auto_update?
      key = key.to_s
      programs = data
      raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
      entry = programs[key]
      entry['episode'] = (entry['episode'] || 0).to_i + 1
      entry['annict_episode_id'] = nil
      if annict && entry['annict_work_id']
        next_ep = next_annict_episode(annict, entry['annict_work_id'], entry['episode'])
        if next_ep
          entry['annict_episode_id'] = next_ep['annictId']
          entry['subtitle'] = next_ep['title'] if next_ep['title']
        end
      end
      save(programs)
      return entry
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
      return value unless key.to_s == 'start_time' && value.is_a?(String)
      hour, minute = value.split(':', 2)
      return value unless minute && hour.match?(/\A\d{1,2}\z/)
      return '%02d:%s' % [hour.to_i, minute]
    end

    # auto_update 有効時は外部 (GAS 等) が番組表データの正本。エディタからの
    # 書き込みは次の pull で上書き消失するので、書き込み API 自体を 409 で
    # 拒否し「auto_update を切ってから編集する」運用に倒す (#4272)。
    def auto_update_conflict
      return Ginseng::ConflictError.new('自動更新が有効のため、編集できません。')
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
