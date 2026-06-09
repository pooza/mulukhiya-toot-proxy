module Mulukhiya
  # 番組表 (Program) の取得・永続化 (I/O) 層 (#4347)。HTTP 取得・サイズ/スキーマ
  # 検証・YAML 永続化・Redis キャッシュを担い、Program 本体は番組表データの参照・
  # 編集 (ドメインロジック) に専念する。Program がメモ化した本クラスのインスタンスへ
  # I/O を委譲する。
  class ProgramFetcher
    include Package

    YAML_PATH = File.join(Environment.dir, 'var/program.yaml').freeze
    REDIS_KEY = 'program'.freeze
    DEFAULT_FETCH_MAX_BYTES = 1_048_576
    DEFAULT_FETCH_TIMEOUT = 30

    def initialize
      @http = HTTP.new
    end

    def uris
      return config['/program/urls'].filter_map {|v| Ginseng::URI.parse(v)}.to_set rescue []
    end

    # 全 URL を取得・検証し、マージした番組表ハッシュを返す。取得対象が無い、または
    # 全 URL 失敗時は nil (呼び出し側で last-known-good を保持する)。
    def fetch
      return nil unless uris.any?
      return fetch_remote
    end

    def save(programs)
      write_yaml(programs)
      return update_cache(programs)
    end

    # キャッシュ (Redis) → YAML の順に番組表データを読む。
    def load
      return cached_data || load_from_yaml
    end

    def yaml_exist?
      return File.exist?(YAML_PATH)
    end

    def invalidate_cache
      return redis.unlink(REDIS_KEY)
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    private

    def fetch_remote
      programs = {}
      success = 0
      uris.each do |v|
        next unless valid_content_length?(v)
        response = @http.get(v, timeout: fetch_timeout)
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

    # HTTParty がレスポンス本文を丸ごとメモリへ読み込む前に、相手が申告した
    # Content-Length が max を超えていれば GET せず弾く。Content-Length 不在や
    # HEAD 非対応 (GatewayError) の場合は判定不能としてそのまま GET へ進み、
    # 受信後の valid_response_size? を最終防衛線とする。
    def valid_content_length?(uri)
      length = @http.head(uri, timeout: fetch_timeout).headers['content-length']
      return true if length.nil? || length.to_i <= fetch_max_bytes
      log_oversize(uri, length.to_i, 'program fetch content-length exceeded max bytes')
      return false
    rescue => e
      # HEAD 非対応・一過性障害は判定不能。GET 側で再評価する。GAS など HEAD を
      # 受け付けないホストは 403/405 を返すが、これは想定内なので黙ってフォール
      # バックし、timeout・5xx 等の異常のみログする (#4397)。
      status = e.respond_to?(:source_status) ? e.source_status : nil
      e.log(url: uri.to_s) unless [403, 405].include?(status)
      return true
    end

    def valid_response_size?(response, uri)
      bytes = response.body.to_s.bytesize
      return true if bytes <= fetch_max_bytes
      log_oversize(uri, bytes, 'program fetch exceeded max bytes')
      return false
    end

    def log_oversize(uri, bytes, message)
      logger.error(message:, url: uri.to_s, bytes:, max_bytes: fetch_max_bytes)
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

    def fetch_timeout
      return config['/program/fetch/timeout'] || DEFAULT_FETCH_TIMEOUT
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
      # SET が中途半端に値を残したまま例外になった場合に備え、不整合な
      # キャッシュを除去して以降の read を YAML フォールバックへ倒す保険。
      # Redis 全断なら UNLINK も失敗するが、その場合は実質キャッシュ無しと
      # 等価なので無害 (best-effort、例外は握り潰す)。
      invalidate_cache rescue nil
      # Redis 書込失敗の根因 (件数・JSON サイズ) を Sentry に残す。
      e.alert(**cache_failure_context(programs))
      return nil
    end

    # alert に添える文脈。programs.to_json が失敗要因だった場合に
    # ここで再 raise すると alert 自体が落ちるため握り潰して空で返す。
    def cache_failure_context(programs)
      return {programs_size: programs.size, json_bytes: programs.to_json.bytesize}
    rescue => e
      e.log
      return {}
    end

    def write_yaml(programs)
      dir = File.dirname(YAML_PATH)
      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, ".program.yaml.#{Process.pid}.#{Thread.current.object_id}")
      File.write(tmp, programs.to_yaml)
      return File.rename(tmp, YAML_PATH)
    end
  end
end
