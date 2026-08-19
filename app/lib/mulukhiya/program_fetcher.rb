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
    # ⚠ Date / Time を許可しないと、**手書きでクォート無しの日付を書いた瞬間に
    # 番組表全体が読めなくなる** (Psych::DisallowedClass)。var/program.yaml は
    # git 管理外で手編集もありうる。5.28.0 の founded_on と同型の footgun なので、
    # 読めるようにしたうえで Program 側で文字列へ寄せる (#4373 / #4537)。
    #
    #   next_on: 2026-08-08          → Date
    #   next_on: 2026-08-08 09:00:00 → Time（時刻まで書くとこちらに落ちる）
    #
    # エディタ経由なら to_yaml が '2026-08-08' とクォートするので無害。
    # 許可クラスは Ginseng::Config::PERMITTED_YAML_CLASSES に揃えてある。
    PERMITTED_YAML_CLASSES = [Symbol, Date, Time].freeze
    NEXT_ON_KEY = 'next_on'.freeze
    # 先頭の YYYY-MM-DD だけを採る。時刻・ゾーンが続いていてもよい (#4558)。
    #
    # ⚠ **後続は「Psych が Time にできる形」だけを許す (PR #4607 の Codex P2)。**
    # `.*` で受けると `next_on: 2026-08-08 garbage` や `2026-08-08 25:99:99` まで
    # 日付へ書き換えてしまう。これらは**元は無効な String のままで、
    # ProgramCalendar が fail-closed していた**もの。書き換えると意図しない話数を
    # 予告・通知しうるので、**壊れた値は壊れたまま残す**（#4585 の shift_next_on と
    # 同じ方針）。時・分・秒は範囲まで見る（`25:99:99` を通さないため）。
    LEADING_DATE_PATTERN = /
      \A(\d{4}-\d{2}-\d{2})
      (?:[Tt\ ]\s*
        (?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d
        (?:\.\d+)?
        (?:\s*(?:[Zz]|[+-](?:[01]\d|2[0-3])(?::?[0-5]\d)?))?
      )?\s*\z
    /x

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
        # allowlist 拒否は HEAD を撃つ前に確定させる。プリフライトの rescue へ
        # 渡すと「判定不能」として GET へ倒れてしまう (#4535)。
        RemoteHost.validate!(v)
        next unless valid_content_length?(v)
        response = @http.get(v, timeout: fetch_timeout, host_validator: RemoteHost.validator)
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
    #
    # host_validator は GET と同じものを渡す。プリフライトだけ無検証だと、GET 側の
    # SSRF ガード (#4410) が「見せかけの安全」になる (#4523)。
    def valid_content_length?(uri)
      length = @http.head(
        uri,
        timeout: fetch_timeout,
        host_validator: RemoteHost.validator,
      ).headers['content-length']
      return true if length.nil? || length.to_i <= fetch_max_bytes
      log_oversize(uri, length.to_i, 'program fetch content-length exceeded max bytes')
      return false
    rescue => e
      # HEAD 非対応・一過性障害は判定不能。GET 側で再評価する。GAS など HEAD を
      # 受け付けないホストは 403/405 を返すが、これは想定内なので黙ってフォール
      # バックし、timeout・5xx 等の異常のみログする (#4397)。
      # ⚠ allowlist 拒否はここへ来ない (呼び出し元の RemoteHost.validate! で
      # 確定済み)。ここを通る = ホストは通ってよい、が保たれている (#4535)。
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
      programs = parse_yaml(File.read(YAML_PATH))
      warm_cache(programs)
      return programs
    end

    # next_on を「書いたとおりの日付」の String として読む (#4558)。
    #
    # ⚠ **Psych が Time にしてしまってからでは、ゾーンレスと明示オフセットを
    # 区別できない。**ゾーンレスの `2026-08-08 18:00:00` は UTC として読まれた
    # うえでローカルへ変換され `2026-08-09 03:00:00 +0900` になる。これは
    # 明示的に `2026-08-09 03:00:00 +09:00` と書いた場合と**同じオブジェクト**で、
    # `utc?` でも `utc_offset` でも判別できない（実測: どちらも
    # `utc? == false` / `utc_offset == 32400`）。前者は getutc 側の日付、後者は
    # 書いたままの日付が正しいので、オブジェクトを見るかぎり両立しない。
    #
    # そこで **materialize する前に** AST 上で next_on のスカラーを、先頭の
    # `YYYY-MM-DD` だけを持つ引用符付きスカラーへ差し替える。時刻もゾーンも
    # 日付の解釈に関与しなくなり、
    #
    #   - `next_on: 2026-08-08 00:30:00 +09:00` が 1 日前へずれる (#4558 項目 2)
    #   - Time が Redis 往復で `"2026-08-08 18:00:00 +0900"` という無効値に化ける
    #     (#4558 項目 1。`to_json` は `to_s` 相当なので JSON にすると型が消える)
    #
    # の両方が同時に消える。⚠ **`PERMITTED_YAML_CLASSES` から Time を外す方向は
    # 採らない**（#4537 が塞いだ「クォート忘れで番組表全体が読めなくなる」
    # footgun が戻る）。ここで潰すのは next_on だけで、他のキーの型は触らない。
    def parse_yaml(source)
      # ⚠ Document 単体は to_yaml できない (STREAM-START が無いと Emitter が
      # 落ちる) ので、Stream として読む。
      ast = YAML.parse_stream(source)
      return {} unless ast.children.present?
      normalize_next_on_nodes(ast)
      # ⚠ AST を直に to_ruby すると permitted_classes が効かない（無制限の
      # ToRuby になる）。一度 YAML へ書き戻して safe_load へ通す。
      return YAML.safe_load(ast.to_yaml, permitted_classes: PERMITTED_YAML_CLASSES) || {}
    end

    def normalize_next_on_nodes(node)
      if node.is_a?(Psych::Nodes::Mapping)
        node.children.each_slice(2) do |key, value|
          normalize_next_on_scalar(value) if next_on_key?(key)
        end
      end
      node.children&.each {|child| normalize_next_on_nodes(child)}
      return node
    end

    def next_on_key?(node)
      return node.is_a?(Psych::Nodes::Scalar) && node.value == NEXT_ON_KEY
    end

    # 先頭が YYYY-MM-DD の形をしていない値（`20260808` や `毎週日曜` 等）は
    # 触らない。妥当性の判定は contract / ProgramCalendar の側にあり、ここで
    # 壊れた値を別の壊れた値へ書き換えない (#4585 の shift_next_on と同じ方針)。
    def normalize_next_on_scalar(node)
      return unless node.is_a?(Psych::Nodes::Scalar)
      return unless (matches = node.value.match(LEADING_DATE_PATTERN))
      node.value = matches[1]
      node.plain = false
      node.quoted = true
      node.style = Psych::Nodes::Scalar::SINGLE_QUOTED
      node.tag = nil
    end

    # 読み経路のキャッシュ温め (#4575)。
    #
    # ⚠ **書き経路の update_cache と違い NX。**load はロックを取らないので、
    # ここを無条件 SET にすると「YAML を読んでから SET するまで」の間に完走した
    # 書き込みを、読み手が古い内容で上書きできる。program キャッシュには TTL が
    # 無く load はキャッシュを優先するため、以後すべての面が旧データを返し続け、
    # 次の編集がそれを read-modify-write して YAML まで巻き戻る（#4534 が塞いだ
    # 症状が、書き手同士でなく「書き手 × 読み手」で復活する）。
    #
    # ⚠ **読み経路をロックに載せる方向は採らない。**読みは書きより桁違いに多く
    # （ProgramUpdateWorker が毎分・API・iCalendar）、409 が跳ね上がる。
    #
    # 温めの失敗は無害（次の read が YAML へ倒れるだけ）なので alert しない。
    def warm_cache(programs)
      return redis.setnx(REDIS_KEY, programs.to_json)
    rescue => e
      e.log(program: {event: 'warm_cache_failed'})
      return false
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
