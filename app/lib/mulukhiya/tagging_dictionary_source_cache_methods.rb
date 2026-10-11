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
      if words = reuse_source(dic)
        return words
      end
      words = dic.parse
      logger.send(words.empty? ? :error : :info, dic: dic.to_h.merge(words: words.count))
      return save_source(dic, words) if words.present?
      @empty_sources.push(dic.uri.to_s)
      clear_fresh(dic)
      return restore_source(dic)
    end

    # 間隔（`dics[].interval`）の内側なら、上流を引かずに直前の成功分を使う (#4690)。
    #
    # 🔴 **上流（GAS）は検証子を返さない**（`ETag` / `Last-Modified` が無く `no-store`・
    # 2026-10-12 実測）ので、条件付き GET では減らせない。滅多に変わらないソースを
    # 長い間隔にするのが、要求を減らす唯一の手。
    # ⚠ **「新しい」印は成功した回にだけ置く**（`save_source`）。失敗した回・last-good で
    # 埋めた回は印が無いので、次の回にまた取りにいく。
    # ⚠ **使い回した回は `@empty_sources` にも `@substituted_sources` にも積まない。**
    # 上流は落ちていない。本数は `@reused_sources` で別に数える。
    # ⚠ 印はあるのに last-good が無い（消えた・壊れた）ときは nil ＝ 取りにいく。
    # ⚠ 手動の更新（`refresh(force: true)`）は印を見ない。取れたら印は置き直される。
    def reuse_source(dic)
      # 🔴 **手動の更新は使い回さない（PR #4828 の Codex P2）。**上流の辞書を直してから
      # 「更新」を押した人に、最大 `interval` ぶん古い内容を返し続けることになる。
      return nil if @force_refresh
      return nil unless source_interval(dic)
      return nil unless redis[fresh_key(dic)]
      raw = redis[source_key(dic)]
      return nil unless raw
      words = Marshal.load(raw) # rubocop:disable Security/MarshalLoad
      return nil unless words.is_a?(Hash) && words.present?
      @reused_sources&.push(dic.uri.to_s)
      logger.info(dic: dic.to_h.merge(words: words.count, reused: true))
      return words
    rescue => e
      e.log(dic: dic.to_h)
      return nil
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
      mark_fresh(dic)
      return words
    rescue => e
      e.log(dic: dic.to_h)
      return words
    end

    # ⚠ **同一性の判定は `RemoteDictionary#cache_signature` に持たせてある。**
    # URL と型だけで割ると、`strict` のように解釈に効く設定が違うソース同士が
    # 互いの last-good を踏み合う（PR #4686 の Codex P2）。
    def source_key(dic)
      return "#{TaggingDictionary::SOURCE_REDIS_KEY_PREFIX}/#{dic.cache_signature}"
    end

    # ⚠ **印の寿命は、取得の周期ぶん短くする。**ワーカーは 10 分おきに回るので、間隔ちょうどの
    # 寿命だと、印が切れる直前の回がもう 1 周期ぶん使い回す（`interval: 3600` が実質 70 分になる）。
    # ⚠ last-good の寿命（`source_ttl`）より長い間隔は意味が無い（先に last-good が切れて取りにいく）。
    def mark_fresh(dic)
      return unless interval = source_interval(dic)
      ttl = interval - TaggingDictionary::FRESH_MARGIN
      redis.setex(fresh_key(dic), ttl, Time.now.to_i.to_s) if ttl.positive?
    end

    # 🔴 **実際に取りにいって失敗した回は、印を消す（PR #4828 の Codex P2）。**印が生きている間の
    # 失敗は手動の更新（`force`）でしか起きないが、消さないと、定時の更新が残りの間隔ぶん
    # 「使い回し」で済ませて取り直さない＝一度の失敗が、上流を見にいかない時間を作る。
    # ⚠ last-good は消さない（埋めるのに使う）。
    def clear_fresh(dic)
      return unless source_interval(dic)
      redis.unlink(fresh_key(dic))
    rescue => e
      e.log(dic: dic.to_h)
    end

    # ⚠ ダブルやサブクラスが `interval` を持たないときは「毎回」。
    def source_interval(dic)
      return nil unless dic.respond_to?(:interval)
      return dic.interval
    end

    # ⚠ **last-good と同じ接頭辞の下に置く。**`invalidate_cache` が一緒に消すので、
    # 「既知の状態から始める」が保たれる。
    def fresh_key(dic)
      return "#{source_key(dic)}/fresh"
    end

    def source_cache_ttl
      ttl = DictionaryTagHandler.handler_config(:cache, :source_ttl)
      return ttl || TaggingDictionary::DEFAULT_SOURCE_CACHE_TTL
    end

    # 全ソースが取得に失敗した回か。⚠ **last-good で埋まったかは見ない**
    # （埋まっても上流が全滅していることに変わりはない）。
    #
    # ⚠⚠ **分母は「実際に試した本数」。**`sources`（設定の本数）とは食い違うことが
    # ある（`RemoteDictionary.create` が落ちた本は `all` に出てこない）。
    # `sources.size` で割ると、**全滅しているのに鳴らない**回ができる。
    def all_sources_empty?
      return false if sources.none?
      attempted = @attempted_sources.to_i
      # ⚠⚠ **設定はあるのに 1 本も組み立てられなかった回も「全滅」（PR #4686 の
      # Codex P2）。**`RemoteDictionary.create` が全部落ちると `attempted` が 0 に
      # なる。ここを false に倒すと、**全ソースが使えないのに Sentry へ何も出ない**。
      return true unless attempted.positive?
      return @empty_sources.to_a.size >= attempted
    end
  end
end
