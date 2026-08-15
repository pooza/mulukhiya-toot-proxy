module Mulukhiya
  # 本文からハッシュタグを引くためのタグ辞書。リモート辞書 (GAS 等) を取り込んで
  # Redis に丸ごとキャッシュし、DictionaryTagHandler / RemoteTagHandler が共有する。
  #
  # ⚠ **キャッシュは「どの dics 設定から作られたか」を署名として持つ (#4583)。**
  # 以前は設定に依らない単一キーへ素の SET (TTL 無し) で書いていたため、
  # 別の dics で温めたキャッシュを次のプロセスがそのまま読み、harness ゲートの
  # 結果が「前に一度回したか」で変わっていた。署名と TTL で、キャッシュの中身を
  # 「いまの設定から作られた、高々 ttl 秒前のもの」に閉じ込める。
  class TaggingDictionary < Hash
    include Package
    include SNSMethods

    REDIS_KEY = 'tagging_dictionary'.freeze
    # キャッシュ payload の形式。envelope を変えたら上げる。旧形式は「無い」ものと
    # して捨てられ、次の refresh で作り直される。
    CACHE_PAYLOAD_VERSION = 1
    DEFAULT_CACHE_TTL = 3600

    def initialize
      super
      @handler = Handler.create(:dictionary_tag)
      @http = HTTP.new
      refresh unless cache.is_a?(Hash)
      update(cache.to_h)
    end

    def clear
      @cache = nil
      @generated_at = nil
      super
    end

    def matches(source)
      text = source.dup
      tags = Concurrent::Array.new
      chunks.reverse_each do |chunk|
        Parallel.each(chunk, in_threads: Parallel.processor_count * 2) do |entry|
          next unless text.match?(entry[:pattern])
          tags.concat(entry[:words])
          text = text.gsub(entry[:pattern], '')
        rescue => e
          e.log(entry:)
        end
      end
      return TagContainer.new(tags.uniq)
    end

    def concat(values)
      values.each do |k, v|
        self[k] ||= v
        self[k][:words] ||= []
        self[k][:words].concat(v[:words]) if v[:words].is_a?(Array)
      rescue => e
        e.log(k:, v:)
      end
      update(sort_by {|k, _| k.length}.to_h)
    end

    # キャッシュされている辞書エントリ。未充填 (初回・TTL 切れ・UNLINK 直後)、
    # 旧形式、別の dics 設定由来なら nil。
    def cache
      @cache ||= load_cache
      return @cache
    end

    # キャッシュを作った時刻。「いまどの取得回の辞書を使っているか」をログ・テスト
    # から見るための世代表示 (#4583)。未充填なら nil。
    def generated_at
      cache
      return @generated_at
    end

    # いまの dics 設定の指紋。これが変われば以前のキャッシュは別物として捨てる。
    def signature
      @signature ||= Digest::SHA256.hexdigest(sources.to_json)
      return @signature
    end

    def refresh
      entries = merge(fetch)
      clear
      if discardable?(entries)
        # ソースはあるのに 1 件も取れなかった回。直近の good を残したまま戻る。
        # ⚠ fail-open 自体は残す (GAS の一過性障害で辞書が消し飛ぶのを防ぐ意図は
        # 正しい)。TTL があるので古い内容が無期限に居座ることはない (#4583)。
        alert_empty_result
        update(cache.to_h)
        return self
      end
      redis.setex(REDIS_KEY, cache_ttl, Marshal.dump(build_payload(entries)))
      update(cache.to_h)
      log_generation
      return self
    rescue => e
      e.alert
      return self
    end

    def short?(word)
      pattern = Regexp.new("^#{@handler.without_kanji_pattern}{,#{@handler.minimum_length - 1}}$")
      return true if word.match?(pattern)
      return word.length < @handler.minimum_length_kanji
    end

    def strict_key?(word)
      key = word.nfkc
      return false unless key?(key)
      return !self[key][:words]&.include?(key)
    end

    def cache_ttl
      return config['/handler/dictionary_tag/cache/ttl'] || DEFAULT_CACHE_TTL
    rescue Ginseng::ConfigError
      # 既定値は config/application.yaml にあるので通常ここへは来ない。設定ファイル
      # が古い環境でも TTL 無しの素の SET へ退行させないための定数フォールバック。
      return DEFAULT_CACHE_TTL
    end

    # キャッシュを捨てる。テスト・運用で「既知の状態から始める」ための入口。
    def self.invalidate_cache
      return Redis.new.unlink(REDIS_KEY)
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    # いまの設定で構成されている辞書ソース。署名と「ソースが 0 本か」の判定に使う。
    def sources
      @sources ||= @handler.all.to_a
      return @sources
    end

    def load_cache
      raw = redis[REDIS_KEY]
      # 未充填は異常ではない。alert しない (TTL を入れた以上、失効は日常的に起きる)。
      return nil unless raw
      payload = Marshal.load(raw) # rubocop:disable Security/MarshalLoad
      return nil unless valid_payload?(payload)
      @generated_at = payload[:generated_at]
      return payload[:entries]
    rescue => e
      # 壊れたキャッシュ。次の refresh で作り直せるので握るが、黙って空にはしない。
      e.log(redis_key: REDIS_KEY)
      return nil
    end

    # 読み込んだ payload がいまの設定のものか。読み辞書側の
    # PronunciationDictionary#valid_schema? と同じで、外れたら型・理由を残す。
    def valid_payload?(payload)
      unless payload.is_a?(Hash) && payload[:entries].is_a?(Hash)
        logger.error(
          message: 'tagging dictionary cache malformed',
          redis_key: REDIS_KEY,
          type: payload.class.name,
        )
        return false
      end
      return true if payload[:version] == CACHE_PAYLOAD_VERSION && payload[:signature] == signature
      # 設定が変わった・古い形式だった、という正常な失効。error にはしない。
      logger.info(
        message: 'tagging dictionary cache discarded',
        redis_key: REDIS_KEY,
        cached_version: payload[:version],
        cached_signature: payload[:signature],
        signature:,
      )
      return false
    end

    # 「ソースは設定されているのに 1 件も取れず、しかも生きたキャッシュがある」回か。
    # ⚠ **サブクラスの parse は失敗を握って {} を返す**ので、例外の数では検出できない。
    # 結果が空かどうかで判定する (#4573 と同型の「黙って空になる」への歯止め)。
    def discardable?(entries)
      return false if entries.present?
      return false if sources.none?
      return cache.present?
    end

    # どの取得回の辞書を使っているかをログに残す。実走のたびに世代が出るので、
    # 「前の実行が温めたキャッシュを読んでいる」状態を後から突き合わせられる。
    def log_generation
      logger.info(
        message: 'tagging dictionary refreshed',
        redis_key: REDIS_KEY,
        signature:,
        generated_at: generated_at&.iso8601,
        sources: sources.size,
        entries: size,
        ttl: cache_ttl,
      )
    end

    def alert_empty_result
      Ginseng::GatewayError.new('tagging dictionary fetch returned nothing').alert(
        redis_key: REDIS_KEY,
        sources: sources.count,
        cached_entries: cache.to_h.size,
        generated_at: generated_at&.iso8601,
      )
    end

    def build_payload(entries)
      return {
        version: CACHE_PAYLOAD_VERSION,
        signature:,
        generated_at: Time.now,
        entries:,
      }
    end

    def fetch
      result = Concurrent::Array.new
      Parallel.each(RemoteDictionary.all, in_threads: Parallel.processor_count * 2) do |dic|
        words = dic.parse
        logger.info(dic: dic.to_h.merge(words: words.count))
        result.push(words)
      rescue => e
        e.log(dic: dic.to_h)
      end
      return result
    end

    def merge(wordsets)
      result = {}
      wordsets.each do |words|
        words.each do |k, v|
          result[k] ||= v
          next unless v[:words].is_a?(Array)
          result[k][:words].concat(v[:words]).uniq!
        end
      end
      return result.sort_by {|k, _| k.length}.to_h
    end

    def chunks
      chunks = Concurrent::Hash.new
      Parallel.each(keys, in_threads: Parallel.processor_count * 2) do |k|
        next if short?(k)
        chunks[k.length] ||= Concurrent::Array.new
        chunks[k.length].push(self[k])
      rescue => e
        e.log(k:)
      end
      return chunks.to_h.values
    end
  end
end
