module Mulukhiya
  # ソース単位の last-good キャッシュ (#4659 の ②)。TaggingDictionary 本体から
  # 切り出してある。
  #
  # ⚠⚠ **切り出したのは行数合わせではなく、「辞書を引く」と「引けなかった回を
  # どう埋めるか」を混ぜないため。**従来の fail-open は `discardable?` の 1 箇所に
  # 埋まっていて、**「全滅したときだけ」しか効かない**ことが読み取りにくかった。
  # 上流の GAS は間欠 404 を返すので、実際に効いてほしいのは**1 本だけ欠けた回**
  # （gomander の実測で 3957 語 → 1814 語まで痩せる）。
  module TaggingDictionarySourceCacheMethods
    private

    # 引く辞書ソースの実体。
    #
    # ⚠ **クラスメソッドを `fetch` の中で直に呼ばない。**last-good の経路 (#4659) を
    # テストするのに `RemoteDictionary.all` をグローバルに差し替えるしかなくなる。
    def remote_dictionaries
      return RemoteDictionary.all.to_a
    end

    # 1 ソースぶんの取得。空だったら last-good で埋める (#4659 の ②)。
    #
    # ⚠⚠ **ログは「取れたか」で出す。**埋めた本数で `:info` を出すと、上流が
    # 404 を返し続けても健全に見える＝ #4573 で塞いだ穴が戻る。`@empty_sources`
    # も取得結果で積むので、台帳・`log_generation` の見え方は変わらない。
    def fetch_source(dic)
      words = dic.parse
      logger.send(words.empty? ? :error : :info, dic: dic.to_h.merge(words: words.count))
      return save_source(dic, words) if words.present?
      @empty_sources.push(dic.uri.to_s)
      return restore_source(dic)
    end

    # ⚠⚠ **1 本欠けた回に痩せた辞書で上書きしない (#4659 の ②)。**現行の fail-open は
    # 「**全滅**したときだけ」前回値を残すので、**1 本だけ 404 になった回はその痩せた
    # 辞書がそのままキャッシュへ書かれていた**。gomander の実測では
    # 3957 語 → **1814 語**（`dic.json` 1 本で半減する）。
    #
    # ⚠ **last-good が無ければ `{}`。**無いものを埋めたと言わない。
    def restore_source(dic)
      raw = redis[source_key(dic)]
      return {} unless raw
      words = Marshal.load(raw) # rubocop:disable Security/MarshalLoad
      return {} unless words.is_a?(Hash)
      @substituted_sources&.push(dic.uri.to_s)
      return words
    rescue => e
      e.log(dic: dic.to_h)
      return {}
    end

    # ⚠ **取り込みの失敗で辞書を落とさない。**last-good が書けなくても、この回の
    # 取得自体は成功している。次の回で書き直せる。
    def save_source(dic, words)
      redis.setex(source_key(dic), source_cache_ttl, Marshal.dump(words))
      return words
    rescue => e
      e.log(dic: dic.to_h)
      return words
    end

    # ⚠⚠ **URL をキーに埋めない。**辞書 URL は `?access_token=` を持つことがあり、
    # Redis のキー一覧は運用の手元にも syslog にも出る (#4511)。ハッシュだけを使う。
    # ⚠ **クラス名も混ぜる。**同じ URL を別の `type` で二重に登録できるので、
    # URL だけだと互いの last-good を踏み合う。
    def source_key(dic)
      digest = Digest::SHA256.hexdigest([dic.class.name, dic.uri.to_s].to_json)
      return "#{TaggingDictionary::SOURCE_REDIS_KEY_PREFIX}/#{digest}"
    end

    def source_cache_ttl
      return config['/handler/dictionary_tag/cache/source_ttl'] || TaggingDictionary::DEFAULT_SOURCE_CACHE_TTL
    rescue Ginseng::ConfigError
      return TaggingDictionary::DEFAULT_SOURCE_CACHE_TTL
    end

    # 全ソースが取得に失敗した回か。⚠ **last-good で埋まったかは見ない**
    # （埋まっても上流が全滅していることに変わりはない）。
    #
    # ⚠⚠ **分母は「実際に試した本数」。**`sources`（設定の本数）とは食い違うことが
    # ある（`RemoteDictionary.create` が落ちた本は `all` に出てこない）。
    # `sources.size` で割ると、**全滅しているのに鳴らない**回ができる。
    def all_sources_empty?
      attempted = @attempted_sources.to_i
      return false unless attempted.positive?
      return @empty_sources.to_a.size >= attempted
    end
  end
end
