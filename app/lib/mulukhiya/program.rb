module Mulukhiya
  class Program
    include Singleton
    include Package

    YAML_PATH = File.join(Environment.dir, 'var/program.yaml').freeze
    REDIS_KEY = 'program'.freeze
    DEFAULT_FETCH_MAX_BYTES = 1_048_576

    def update
      return nil unless auto_update?
      return nil unless uris.any?
      programs = fetch_remote
      return nil unless programs
      return save(programs)
    end

    def auto_update?
      return config['/program/auto_update'] != false
    end

    def save(programs)
      write_yaml(programs)
      return update_cache(programs)
    end

    def data
      raw = cached_data || load_from_yaml
      return raw.each_with_object({}) do |(key, entry), result|
        next unless entry.is_a?(Hash)
        result[key] = entry.merge('extra_tags' => entry['extra_tags'] || [])
      end
    end

    def add_entry(key, attributes)
      key = key.to_s
      raise Ginseng::ValidateError, 'キーが空です。' if key.empty?
      programs = data
      raise Ginseng::ConflictError, "キー '#{key}' は既に存在します。" if programs.key?(key)
      programs[key] = attributes.transform_keys(&:to_s).compact
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
      key = key.to_s
      programs = data
      raise Ginseng::NotFoundError, "キー '#{key}' が見つかりません。" unless programs.key?(key)
      attributes.each do |k, v|
        if v.nil?
          programs[key].delete(k.to_s)
        else
          programs[key][k.to_s] = v
        end
      end
      save(programs)
      return programs[key]
    end

    def delete_entry(key)
      key = key.to_s
      programs = data
      return nil unless programs.key?(key)
      entry = programs.delete(key)
      save(programs)
      return entry
    end

    def increment_episode(key, annict: nil)
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

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def count
      return data.count
    end

    def to_yaml
      return data.to_yaml
    end

    def uris
      return config['/program/urls'].filter_map {|v| Ginseng::URI.parse(v)}.to_set rescue []
    end

    def yaml_exist?
      return File.exist?(YAML_PATH)
    end

    def invalidate_cache
      redis.unlink(REDIS_KEY)
    end

    alias to_s to_yaml

    private

    def initialize
      @http = HTTP.new
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

    def fetch_remote
      programs = {}
      success = 0
      uris.each do |v|
        response = @http.get(v)
        next unless valid_response_size?(response, v)
        parsed = response.parsed_response
        next unless valid_program_schema?(parsed, v)
        programs.merge!(parsed)
        success += 1
      rescue => e
        # 単一 URL の取得失敗 (HTTP error / parse error 等) で update 全体が落ちる
        # のを防ぐ。失敗した URL のみ skip し、他の URL の取り込みは続ける
        e.log(url: v.to_s)
      end
      # 全 URL が失敗した場合は last-known-good を保持するため nil を返し
      # 上位の update() で save をスキップする (一過性障害で YAML 全消失を防ぐ)
      return nil if success.zero?
      return programs
    end

    def valid_response_size?(response, uri)
      bytes = response.body.to_s.bytesize
      max = fetch_max_bytes
      return true if bytes <= max
      logger.error(
        message: 'program fetch exceeded max bytes',
        url: uri.to_s,
        bytes:,
        max_bytes: max,
      )
      return false
    end

    def valid_program_schema?(parsed, uri)
      return true if parsed.is_a?(Hash) && parsed.values.all?(Hash)
      logger.error(
        message: 'program fetch schema invalid',
        url: uri.to_s,
        type: parsed.class.name,
      )
      return false
    end

    def fetch_max_bytes
      return config['/program/fetch/max_bytes'] || DEFAULT_FETCH_MAX_BYTES
    end

    def cached_data
      raw = redis[REDIS_KEY]
      return nil unless raw
      return JSON.parse(raw)
    end

    def load_from_yaml
      return {} unless yaml_exist?
      programs = YAML.safe_load_file(YAML_PATH, permitted_classes: [Symbol]) || {}
      update_cache(programs)
      return programs
    end

    def update_cache(programs)
      return redis[REDIS_KEY] = programs.to_json
    rescue => e
      invalidate_cache rescue nil
      e.alert
      return nil
    end

    def write_yaml(programs)
      dir = File.dirname(YAML_PATH)
      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, ".program.yaml.#{Process.pid}.#{Thread.current.object_id}")
      File.write(tmp, programs.to_yaml)
      File.rename(tmp, YAML_PATH)
    end
  end
end
