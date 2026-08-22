module Mulukhiya
  # タグ辞書キャッシュの健全性 (#4583) の回帰テスト。
  #
  # ⚠ **TaggingDictionaryTest と分けてあるのは、あちらが DB 前提だから。**
  # `Handler.create(:dictionary_tag)` は Sequel のモデルを触るので、DB の無い環境
  # では TaggingDictionary をそのまま new できず、クラスごと omission になる。
  # キャッシュの世代・署名・TTL は辞書ソースの設定だけで決まり、ハンドラの実体を
  # 必要としないので、辞書ソースを返すだけのダブルを差し込んで常に実走させる。
  # #4503 の教訓どおり、ゲートを守るテストが環境次第で omission になるのは避ける。
  class TaggingDictionaryCacheTest < TestCase
    DICS = [
      {'url' => 'https://example.jp/api/dic/v1/a.json', 'type' => 'related'},
      {'url' => 'https://example.jp/api/dic/v1/b.json'},
    ].freeze

    ENTRY_KEYS = ['キュアスタ'].freeze

    def setup
      @dic = create_dictionary(DICS)
    end

    def teardown
      super
      # 実設定と署名が合わないので本番経路からは読まれないが、後続のテストに
      # 余計なキーを残さない。
      TaggingDictionary.invalidate_cache
    rescue => e
      e.log
    end

    def test_cache_ttl
      assert_kind_of(Integer, @dic.cache_ttl)
      assert_predicate(@dic.cache_ttl, :positive?)
    end

    # 素の SET (TTL 無し) へ退行していないことを、実際の Redis の TTL で確かめる。
    # これが -1 だと「前に一度回したか」でゲートの結果が変わる (#4583)。
    def test_refresh_sets_ttl
      @dic.refresh
      ttl = redis.redis.call('TTL', TaggingDictionary::REDIS_KEY)

      assert_predicate(ttl, :positive?, "tagging_dictionary の TTL が #{ttl}")
      assert_operator(ttl, :<=, @dic.cache_ttl)
    end

    def test_refresh_stamps_generation
      @dic.refresh

      assert_not_nil(@dic.generated_at)
      assert_equal(ENTRY_KEYS, @dic.keys)

      payload = load_payload

      assert_equal(TaggingDictionary::CACHE_PAYLOAD_VERSION, payload[:version])
      assert_equal(@dic.signature, payload[:signature])
      assert_equal(ENTRY_KEYS, payload[:entries].keys)
      assert_kind_of(Time, payload[:generated_at])
    end

    def test_signature_follows_dics
      assert_not_equal(@dic.signature, create_dictionary(DICS.take(1)).signature)
      assert_not_equal(
        @dic.signature,
        create_dictionary([{'url' => DICS.first['url'], 'type' => 'mecab'}, DICS.last]).signature,
      )
    end

    # ⚠ **署名は「畳む前」と「畳んだ後」で同じでなければならない。**
    # `type` の既定値・旧称 (`relative` → `related`) は `RemoteDictionary.create`
    # の中で解決されるが、そこで設定ハッシュを書き換えていたので、キャッシュを
    # 書いたプロセスと起動直後のプロセスで指紋が食い違い、**毎回キャッシュを捨てて
    # 全辞書を同期取得していた** (PR #4587 の Codex P2)。
    def test_signature_is_stable_across_type_normalization
      dics = [
        {'url' => 'https://example.jp/api/dic/v1/a.json', 'type' => 'relative'},
        {'url' => 'https://example.jp/api/dic/v1/b.json'},
      ]
      before = create_dictionary(dics.map(&:dup)).signature
      # 本番では fetch (RemoteDictionary.create) が通ったあとの状態にあたる。
      dics.each {|v| RemoteDictionary.type(v)}

      assert_equal(before, create_dictionary(dics).signature)
    end

    # 既定値・旧称は同じソースとして扱う。設定の書き方だけでキャッシュが
    # 捨てられないこと。
    def test_signature_ignores_type_aliases
      related = create_dictionary([{'url' => 'https://example.jp/a.json', 'type' => 'related'}])
      relative = create_dictionary([{'url' => 'https://example.jp/a.json', 'type' => 'relative'}])
      implicit = create_dictionary([{'url' => 'https://example.jp/b.json'}])
      explicit = create_dictionary([
        {'url' => 'https://example.jp/b.json', 'type' => 'multi_field'},
      ])

      assert_equal(related.signature, relative.signature)
      assert_equal(implicit.signature, explicit.signature)
    end

    # ⚠ 設定ハッシュは共有物。`create` が書き換えると署名が動く。
    def test_create_does_not_mutate_config
      params = {'url' => 'https://example.jp/a.json', 'type' => 'relative'}
      RemoteDictionary.create(params)

      assert_equal('relative', params['type'])
    end

    # 別の dics 設定で温めたキャッシュを読まない。これが #4583 の芯で、
    # 「前に誰が回したか」で辞書の中身が変わるのを断つ。
    def test_cache_ignores_foreign_signature
      @dic.refresh

      assert_equal(ENTRY_KEYS, @dic.cache.to_h.keys)

      other = create_dictionary(DICS.take(1))

      assert_nil(other.cache)
      assert_nil(other.generated_at)
    end

    def test_cache_ignores_legacy_payload
      # 旧形式 = エントリの生ハッシュを直に Marshal したもの
      redis[TaggingDictionary::REDIS_KEY] = Marshal.dump(build_entries)

      assert_nil(create_dictionary(DICS).cache)
    end

    def test_cache_ignores_broken_payload
      redis[TaggingDictionary::REDIS_KEY] = 'not a marshal dump'

      assert_nil(create_dictionary(DICS).cache)
    end

    def test_cache_absent_is_not_an_error
      TaggingDictionary.invalidate_cache

      assert_nil(@dic.cache)
      assert_nil(@dic.generated_at)
    end

    # 全ソースが空を返した回で、生きているキャッシュを空へ潰さない (#4583)。
    # ⚠ RemoteDictionary のサブクラスは失敗を握って {} を返すので、例外の有無では
    # 検出できない。結果が空かどうかで判定していることを押さえる。
    def test_refresh_keeps_last_known_good
      @dic.refresh
      generated_at = @dic.generated_at

      empty = create_dictionary(DICS, wordsets: [])
      empty.refresh

      assert_equal(ENTRY_KEYS, empty.cache.to_h.keys)
      assert_equal(ENTRY_KEYS, empty.keys)
      assert_equal(generated_at, empty.generated_at)
    end

    # ソースが 1 本も無いなら空が正しい結果。歯止めを効かせない。
    def test_refresh_persists_empty_without_sources
      @dic.refresh

      none = create_dictionary([], wordsets: [])
      none.refresh

      assert_equal({}, none.cache.to_h)
      assert_empty(none)
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def load_payload
      return Marshal.load(redis[TaggingDictionary::REDIS_KEY]) # rubocop:disable Security/MarshalLoad
    end

    # merge は wordset の中身 (words 配列) を破壊的に触るので、呼ばれるたびに
    # 作り直したものを渡す。
    def build_entries
      return ENTRY_KEYS.to_h do |key|
        [key, {pattern: Regexp.new(key), regexp: key, words: [key]}]
      end
    end

    def create_dictionary(dics, wordsets: nil)
      dic = TaggingDictionary.allocate
      dic.instance_variable_set(:@handler, Struct.new(:all).new(dics))
      builder = -> {wordsets || [build_entries]}
      dic.define_singleton_method(:fetch) {builder.call}
      return dic
    end
  end
end
