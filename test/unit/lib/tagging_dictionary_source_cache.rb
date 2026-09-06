module Mulukhiya
  # ソース単位の last-good キャッシュ (#4659 の ②) の回帰テスト。
  #
  # ⚠⚠ **従来の fail-open は「全滅したときだけ」前回値を残していた。**上流の GAS が
  # 間欠 404 を返すと、**1 本だけ欠けた回はその痩せた辞書でキャッシュが上書きされる**。
  # gomander の実測では 3957 語 → **1814 語**（`dic.json` 1 本で半減）で、
  # **辞書が半分になった状態でニチアサの実況の窓に入っていた**。
  #
  # ⚠ TaggingDictionaryCacheTest と同じく、`Handler.create(:dictionary_tag)` が
  # DB を触るので `allocate` で組む（#4503 の教訓どおり環境で omission にしない）。
  class TaggingDictionarySourceCacheTest < TestCase
    # `TaggingDictionary#fetch_source` が触るのは `parse` / `uri` / `to_h` だけ。
    class SourceDouble
      attr_reader :uri

      def self.build(url, words)
        double = allocate
        double.instance_variable_set(:@uri, Ginseng::URI.parse(url))
        double.instance_variable_set(:@words, words)
        return double
      end

      def parse = @words

      attr_writer :words, :strict

      def to_h = {uri: uri.to_s}

      # 本物と同じく「解釈に効く設定まで含めた」同一性を返す。
      def cache_signature
        return Digest::SHA256.hexdigest([self.class.name, uri.to_s, @strict].to_json)
      end
    end

    URL = 'https://example.jp/api/dic/v1/a.json?access_token=deadbeef'.freeze

    def setup
      TaggingDictionary.invalidate_cache
      @source = SourceDouble.build(URL, entries)
      @dic = build_dictionary([@source])
    end

    def teardown
      super
      TaggingDictionary.invalidate_cache
    rescue => e
      e.log
    end

    # 取れた回は last-good として保存し、そのまま返す。
    def test_successful_fetch_is_saved
      assert_equal(entries, fetch_source(@source))
      assert_empty(@dic.instance_variable_get(:@empty_sources).to_a)
      assert_empty(@dic.instance_variable_get(:@substituted_sources).to_a)
      assert_equal(entries, restore_source(@source))
    end

    # ⚠⚠ **これが本命。**空を返した回は last-good で埋める。
    def test_empty_fetch_is_substituted
      fetch_source(@source)
      reset_counters
      @source.words = {}

      assert_equal(entries, fetch_source(@source))
      # 埋めても「取れなかった」ことは記録し続ける（台帳・#4573 の観測を壊さない）。
      assert_equal([URL], @dic.instance_variable_get(:@empty_sources).to_a)
      assert_equal([URL], @dic.instance_variable_get(:@substituted_sources).to_a)
    end

    # ⚠ **無いものを埋めたと言わない。**last-good が無ければ空のまま。
    def test_empty_fetch_without_last_good
      @source.words = {}

      assert_empty(fetch_source(@source))
      assert_equal([URL], @dic.instance_variable_get(:@empty_sources).to_a)
      assert_empty(@dic.instance_variable_get(:@substituted_sources).to_a)
    end

    def test_source_cache_has_ttl
      fetch_source(@source)
      ttl = redis.redis.call('TTL', @dic.send(:source_key, @source))

      assert_predicate(ttl, :positive?, "source cache の TTL が #{ttl}")
      assert_operator(ttl, :<=, @dic.send(:source_cache_ttl))
    end

    # ⚠ **本体より長く持つ。**同じ TTL だと、続けて外したソースの last-good が
    # 先に消えて意味を成さない。
    def test_source_ttl_outlives_the_main_cache
      assert_operator(@dic.send(:source_cache_ttl), :>, @dic.cache_ttl)
    end

    # ⚠⚠ **URL をキーに埋めない (#4511)。**辞書 URL は `?access_token=` を持つ。
    def test_source_key_does_not_leak_the_url
      key = @dic.send(:source_key, @source)

      assert(key.start_with?("#{TaggingDictionary::SOURCE_REDIS_KEY_PREFIX}/"))
      assert_not_include(key, 'example.jp')
      assert_not_include(key, 'access_token')
      assert_not_include(key, 'deadbeef')
    end

    # 同じ URL を別の type で二重に登録できるので、互いの last-good を踏まないこと。
    def test_source_key_separates_classes
      other = Class.new(SourceDouble).build(URL, entries)

      assert_not_equal(@dic.send(:source_key, @source), @dic.send(:source_key, other))
    end

    def test_source_key_separates_parsing_options
      other = SourceDouble.build(URL, entries)
      other.strict = true

      assert_not_equal(@dic.send(:source_key, @source), @dic.send(:source_key, other))
    end

    def test_source_key_separates_urls
      other = SourceDouble.build('https://example.jp/api/dic/v1/b.json', entries)

      assert_not_equal(@dic.send(:source_key, @source), @dic.send(:source_key, other))
    end

    # 壊れた last-good を掴んでも落ちない。次の取得で書き直せる。
    def test_broken_last_good_is_ignored
      redis[@dic.send(:source_key, @source)] = 'not a marshal dump'

      assert_empty(restore_source(@source))
    end

    def test_invalidate_cache_drops_source_keys
      fetch_source(@source)
      TaggingDictionary.invalidate_cache

      assert_empty(restore_source(@source))
    end

    # ⚠⚠ **全滅は last-good で埋めても鳴らす。**埋まると entries は present に
    # なるので `discardable?` を通らない。ここで鳴らさないと、**全ソースが死んでも
    # Sentry には何も出なくなる**。
    def test_all_sources_empty_is_detected_even_when_substituted
      fetch_source(@source)
      reset_counters
      @dic.instance_variable_set(:@attempted_sources, 1)
      @source.words = {}
      fetch_source(@source)

      assert_true(@dic.send(:all_sources_empty?))
    end

    def test_all_sources_empty_is_false_when_something_was_fetched
      @dic.instance_variable_set(:@attempted_sources, 2)
      fetch_source(@source)

      assert_false(@dic.send(:all_sources_empty?))
    end

    # ⚠ 1 本でも取れていれば全滅ではない（残りが空でも）。
    def test_all_sources_empty_is_false_with_a_partial_failure
      other = SourceDouble.build('https://example.jp/api/dic/v1/b.json', {})
      dic = build_dictionary([@source, other])
      dic.instance_variable_set(:@attempted_sources, 2)
      dic.send(:fetch_source, @source)
      dic.send(:fetch_source, other)

      assert_false(dic.send(:all_sources_empty?))
    end

    # ソースが 1 本も設定されていない回を「全滅」と言わない。
    def test_all_sources_empty_without_sources
      assert_false(build_dictionary.send(:all_sources_empty?))
    end

    # ⚠⚠ **設定はあるのに 1 本も組み立てられなかった回は「全滅」（PR #4686 の
    # Codex P2）。**`RemoteDictionary.create` が全部落ちると `attempted` が 0 になる。
    # ここを取り逃がすと、全ソースが使えないのに Sentry へ何も出ない。
    def test_all_sources_empty_when_nothing_could_be_built
      dic = build_dictionary([@source])
      dic.instance_variable_set(:@attempted_sources, 0)

      assert_true(dic.send(:all_sources_empty?))
    end

    # ⚠⚠ **解釈に効く設定が違えば別のキー（PR #4686 の Codex P2）。**
    # 同じ URL・同じ type でも `strict` で entries が変わるので、踏み合うと
    # 別設定の辞書で埋めたものが本体キャッシュへ最大 24 時間居座る。
    def test_cache_signature_follows_parsing_options
      loose = RemoteDictionary.create({'url' => URL, 'type' => 'related'})
      strict = RemoteDictionary.create({'url' => URL, 'type' => 'related', 'strict' => true})

      assert_not_equal(loose.cache_signature, strict.cache_signature)
      assert_not_equal(@dic.send(:source_key, loose), @dic.send(:source_key, strict))
    end

    def test_cache_signature_does_not_leak_the_url
      signature = RemoteDictionary.create({'url' => URL, 'type' => 'related'}).cache_signature

      assert_not_include(signature, 'example.jp')
      assert_not_include(signature, 'deadbeef')
    end

    # `refresh` を通した振る舞い。1 本欠けても辞書が痩せないこと。
    def test_refresh_does_not_thin_the_dictionary
      alive = SourceDouble.build('https://example.jp/a.json', entries('キュアスタ'))
      flaky = SourceDouble.build('https://example.jp/b.json', entries('デルムリン'))
      dic = build_dictionary([alive, flaky])
      dic.refresh

      assert_equal(['キュアスタ', 'デルムリン'].sort, dic.keys.sort)

      # 次の回で b.json だけが 404 になる。
      flaky.words = {}
      dic = build_dictionary([alive, flaky])
      dic.refresh

      assert_equal(['キュアスタ', 'デルムリン'].sort, dic.keys.sort)
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    # merge / concat は words 配列を破壊的に触るので、呼ばれるたびに作り直す。
    def entries(key = 'キュアスタ')
      return {key => {pattern: Regexp.new(key), regexp: key, words: [key]}}
    end

    def fetch_source(source)
      return @dic.send(:fetch_source, source)
    end

    def restore_source(source)
      return @dic.send(:restore_source, source)
    end

    def reset_counters
      @dic.instance_variable_set(:@empty_sources, Concurrent::Array.new)
      @dic.instance_variable_set(:@substituted_sources, Concurrent::Array.new)
    end

    def build_dictionary(dics = [])
      dic = TaggingDictionary.allocate
      # ⚠ **設定は文字列キー。**`canonical_sources` は `to_h.merge('type' => ...)`
      # を `sort` するので、シンボルキーを混ぜると Symbol と String の比較で落ちる。
      config = dics.map {|dic| {'url' => dic.uri.to_s}}
      dic.instance_variable_set(:@handler, Struct.new(:all).new(config))
      dic.define_singleton_method(:remote_dictionaries) {dics}
      dic.instance_variable_set(:@empty_sources, Concurrent::Array.new)
      dic.instance_variable_set(:@substituted_sources, Concurrent::Array.new)
      return dic
    end
  end
end
