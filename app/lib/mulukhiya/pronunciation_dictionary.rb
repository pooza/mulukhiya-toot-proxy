module Mulukhiya
  # capsicum 投稿サジェスト (#4397 / capsicum#614) 向けの読み付き単語辞書。
  #
  # サーバー固有の GAS エンドポイント (precure.ml /api/dic/v1/pron.json /
  # mstdn.delmulin.com /api/dic/v1/pronunciations.json 等) が出力する
  # [{word, pronunciation, category?}] を取り込み、読み (カタカナ) で引ける
  # 候補リストとして Redis にキャッシュする。更新は
  # PronunciationDictionaryUpdateWorker が定期実行する。
  #
  # データの正本は各サーバー 1 枚のスプレッドシート (GAS が dic.json と
  # pron.json を同一シートから投影している)。モロヘイヤは揮発キャッシュのみを
  # 持ち、辞書の写しを永続化しない (二重管理の回避)。
  class PronunciationDictionary
    include Package

    REDIS_KEY = 'pronunciation_dictionary'.freeze
    DEFAULT_FETCH_MAX_BYTES = 1_048_576
    DEFAULT_FETCH_TIMEOUT = 30
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100

    def initialize
      @http = HTTP.new
    end

    def enabled?
      return uris.any?
    end

    def uris
      return config['/word_suggest/urls'].filter_map {|v| Ginseng::URI.parse(v)} rescue []
    end

    def entries
      @entries ||= cached_entries || (update && cached_entries) || []
    end

    def size
      return entries.size
    end

    # 読み (主にひらがな) で前方一致 → 表層前方一致 → 部分一致の順に候補を返す。
    # surface / reading は固定で返し、category はソースにあれば添える (任意)。
    def suggest(query, limit: DEFAULT_LIMIT)
      surface_query = query.to_s.strip
      reading_query = normalize_reading(surface_query)
      return [] if reading_query.empty?
      limit = clamp_limit(limit)
      scored = entries.filter_map do |entry|
        rank = match_rank(entry, reading_query, surface_query)
        next unless rank
        [rank, entry['reading'].to_s, entry]
      end
      # 同ランク内は読み (カタカナ) の五十音順 → 短い順。前方一致優先 (rank) は
      # 維持しつつ、同ランクではふりがな辞書順で安定して並べる (#4397)。
      ranked = scored.sort_by {|rank, reading, _entry| [rank, reading, reading.length]}
      return ranked.first(limit).map {|_, _, entry| present(entry)}
    end

    def update
      entries = fetch_remote
      return nil unless entries
      return save(entries)
    end

    def invalidate_cache
      @entries = nil
      return redis.unlink(REDIS_KEY)
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    private

    # 候補マッチの優先度。小さいほど上位。マッチしなければ nil。
    def match_rank(entry, reading_query, surface_query)
      reading = entry['reading'].to_s
      surface = entry['surface'].to_s
      return 0 if reading.start_with?(reading_query)
      return 1 if surface_query.present? && surface.start_with?(surface_query)
      return 2 if reading.include?(reading_query)
      return nil
    end

    def present(entry)
      result = {surface: entry['surface'], reading: entry['reading']}
      result[:category] = entry['category'] if entry['category'].present?
      return result
    end

    # ひらがな↔カタカナ・全半角の揺れを吸収しカタカナへ正規化する。ユーザーが
    # 打鍵できるのはひらがな読みなので、検索キーと辞書側 pronunciation を同じ
    # カタカナ空間に寄せて突き合わせる (proxy 哲学に従い正規化はモロヘイヤ側で
    # 吸収する)。
    def normalize_reading(value)
      return value.to_s.nfkc.tr('ぁ-ゖ', 'ァ-ヶ').strip
    end

    def clamp_limit(limit)
      # limit[]=1 のように配列/ハッシュで渡されると to_i が無く 500 になるため、
      # スカラー以外・非正値は既定値に倒す (公開クエリを 500 にしない)。
      return DEFAULT_LIMIT unless limit.respond_to?(:to_i)
      limit = limit.to_i
      return DEFAULT_LIMIT unless limit.positive?
      return [limit, MAX_LIMIT].min
    end

    def fetch_remote
      entries = []
      success = 0
      uris.each do |uri|
        rows = fetch_one(uri)
        next unless rows
        entries.concat(rows)
        success += 1
      rescue => e
        # 単一 URL の取得失敗で update 全体が落ちるのを防ぐ。失敗 URL のみ skip。
        e.log(url: uri.to_s)
      end
      # 全 URL が失敗した場合は last-known-good を保持するため nil を返し、上位の
      # update() で save をスキップする (GAS の一過性障害で候補が全消失するのを防ぐ)。
      return nil if success.zero?
      return dedup(entries)
    end

    def fetch_one(uri)
      return nil unless valid_content_length?(uri)
      response = @http.get(uri, timeout: fetch_timeout)
      return nil unless valid_response_size?(response, uri)
      parsed = response.parsed_response
      return nil unless valid_schema?(parsed, uri)
      return normalize_entries(parsed)
    end

    # 複数サーバーで同一の表層形+読みが重複した場合は先勝ちで 1 件に畳む。
    def dedup(entries)
      seen = Set.new
      return entries.select {|entry| seen.add?([entry['surface'], entry['reading']])}
    end

    def normalize_entries(parsed)
      return parsed.filter_map do |row|
        next unless row.is_a?(Hash)
        surface = row['word'].to_s.strip
        reading = normalize_reading(row['pronunciation'])
        next if surface.empty? || reading.empty?
        entry = {'surface' => surface, 'reading' => reading}
        category = row['category'].to_s.strip
        entry['category'] = category unless category.empty?
        entry
      end
    end

    # HTTParty が本文を丸ごとメモリへ読み込む前に、相手が申告した Content-Length が
    # max を超えていれば GET せず弾く。Content-Length 不在・HEAD 非対応の場合は判定
    # 不能としてそのまま GET へ進み、受信後の valid_response_size? を最終防衛線とする。
    def valid_content_length?(uri)
      length = @http.head(uri, timeout: fetch_timeout).headers['content-length']
      return true if length.nil? || length.to_i <= fetch_max_bytes
      log_oversize(uri, length.to_i, 'word_suggest fetch content-length exceeded max bytes')
      return false
    rescue => e
      # GAS など HEAD 非対応のホストは 403/405 を返す。これは想定内なので黙って GET へ
      # フォールバックし (GET 側 valid_response_size? が最終防衛線)、timeout・5xx 等の
      # 異常のみログする。GAS は Content-Length も返さず事前チェックは効かない (#4397)。
      status = e.respond_to?(:source_status) ? e.source_status : nil
      e.log(url: uri.to_s) unless [403, 405].include?(status)
      return true
    end

    def valid_response_size?(response, uri)
      bytes = response.body.to_s.bytesize
      return true if bytes <= fetch_max_bytes
      log_oversize(uri, bytes, 'word_suggest fetch exceeded max bytes')
      return false
    end

    def log_oversize(uri, bytes, message)
      logger.error(message:, url: uri.to_s, bytes:, max_bytes: fetch_max_bytes)
    end

    def valid_schema?(parsed, uri)
      valid = parsed.is_a?(Array) && parsed.all? do |row|
        row.is_a?(Hash) && row.key?('word') && row.key?('pronunciation')
      end
      return true if valid
      logger.error(
        message: 'word_suggest fetch schema invalid',
        url: uri.to_s,
        type: parsed.class.name,
      )
      return false
    end

    def fetch_max_bytes
      return config['/word_suggest/fetch/max_bytes'] || DEFAULT_FETCH_MAX_BYTES
    end

    def fetch_timeout
      return config['/word_suggest/fetch/timeout'] || DEFAULT_FETCH_TIMEOUT
    end

    def cached_entries
      raw = redis[REDIS_KEY]
      return nil unless raw
      return parse_cached_entries(raw)
    rescue => e
      # Redis 接続障害などの読み取り失敗。公開 /word/suggest から per-request で
      # 呼ばれるため alert すると Redis 全断時に Sentry スパム化する。ログのみに
      # 留め、上位 (entries) を update → fetch フォールバックへ倒す (#4397)。
      e.log
      return nil
    end

    def parse_cached_entries(raw)
      parsed = JSON.parse(raw)
      return parsed.is_a?(Array) ? parsed : nil
    rescue => e
      # キャッシュ本体の破損 (不正 JSON / 非配列)。一過性ではなく要対処なので
      # alert し、壊れたキャッシュを除去して以降の read を fetch へ倒す。
      invalidate_cache rescue nil
      e.alert
      return nil
    end

    def save(entries)
      @entries = nil
      redis[REDIS_KEY] = entries.to_json
      return entries
    rescue => e
      # 中途半端なキャッシュを除去し以降の read を fetch フォールバックへ倒す保険。
      invalidate_cache rescue nil
      e.alert(entries_size: entries.size)
      return nil
    end
  end
end
