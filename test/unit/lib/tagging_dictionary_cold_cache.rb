module Mulukhiya
  # 本体キャッシュが無い・切れそうなときの振る舞い (#4628 の 2 件目・9 件目)。
  #
  # 🔴 **投稿の経路（`TaggingDictionary.new`）は上流へ取りにいかない。**以前はここで
  # `refresh` を同期で呼んでいたので、本体キャッシュが切れた瞬間に、届いた投稿すべてが
  # 全ソースを取りにいっていた。
  #
  # ⚠ TaggingDictionarySourceCacheTest と同じく `allocate` で組む（環境で omission にしない）。
  class TaggingDictionaryColdCacheTest < TestCase
    # ⚠ 上流を引いた回数（`parsed`）を数える。「引かずに済ませた」ことを見るため。
    class SourceDouble
      attr_reader :uri
      attr_writer :words

      def self.build(url, words)
        double = allocate
        double.instance_variable_set(:@uri, Ginseng::URI.parse(url))
        double.instance_variable_set(:@words, words)
        return double
      end

      def parse
        @parsed = @parsed.to_i + 1
        return @words
      end

      def parsed = @parsed.to_i

      def to_h = {uri: uri.to_s}

      def cache_signature
        return Digest::SHA256.hexdigest([self.class.name, uri.to_s].to_json)
      end
    end

    URL = 'https://example.jp/api/dic/v1/a.json?access_token=deadbeef'.freeze

    def setup
      TaggingDictionary.invalidate_cache
      @requests = requests = []
      TaggingDictionaryUpdateWorker.define_singleton_method(:perform_async) do |*args|
        requests.push(args)
      end
      @source = SourceDouble.build(URL, entries)
      @dic = build_dictionary([@source])
    end

    def teardown
      super
      TaggingDictionaryUpdateWorker.singleton_class.send(:remove_method, :perform_async)
      TaggingDictionary.invalidate_cache
    rescue => e
      e.log
    end

    # 🔴 これが本命。last-good があれば、上流を引かずにそこから組み立てる。
    def test_cold_cache_is_restored_without_fetching
      warm_last_good
      @dic.send(:fill_cold_cache)

      assert_equal(entries, @dic.cache)
      assert_equal(0, @source.parsed)
    end

    # ⚠ 組み立てた辞書は本体キャッシュへ書かない（古い内容に「いま作った」印を付けない）。
    def test_restored_entries_are_not_published
      warm_last_good
      @dic.send(:fill_cold_cache)

      assert_nil(redis[TaggingDictionary::REDIS_KEY])
    end

    # last-good も無ければ空。⚠ それでも上流は引かない（投稿は辞書タグなしで通す）。
    def test_cold_cache_without_last_good_is_empty
      @dic.send(:fill_cold_cache)

      assert_empty(@dic.cache)
      assert_equal(0, @source.parsed)
    end

    # ⚠⚠ 更新の依頼は 1 回だけ。投稿の数だけジョブを積まない。
    def test_refresh_is_requested_once
      3.times {build_dictionary([@source]).send(:fill_cold_cache)}

      assert_equal([[{'cold' => true}]], @requests)
    end

    # ⚠ ログも依頼を出せた回だけ（投稿のたびに出すと syslog が埋まる）。
    def test_cold_is_logged_once
      warm_last_good
      logged = 2.times.flat_map do
        dic = build_dictionary([@source])
        capture_log(dic) {dic.send(:fill_cold_cache)}
      end
      cold = logged.select {|v| v[:message] == 'tagging dictionary cold'}

      assert_equal(1, cold.size)
      assert_equal(1, cold.first[:restored_sources])
      assert_equal(1, cold.first[:entries])
    end

    # development / test では依頼がその場で走る。本体キャッシュが埋まったらそれを使う。
    def test_synchronously_filled_cache_is_used
      dic = @dic
      TaggingDictionaryUpdateWorker.define_singleton_method(:perform_async) {|*| dic.refresh}
      @dic.send(:fill_cold_cache)

      assert_equal(entries, @dic.cache)
      assert_not_nil(@dic.generated_at)
    end

    # ⚠ 依頼が落ちても投稿は通す。
    def test_failed_request_does_not_raise
      warm_last_good
      TaggingDictionaryUpdateWorker.define_singleton_method(:perform_async) {|*| raise 'boom'}
      @dic.send(:fill_cold_cache)

      assert_equal(entries, @dic.cache)
    end

    # 辞書を 1 本も持たないサーバーは、依頼も出さない。
    def test_no_sources_requests_nothing
      dic = build_dictionary([])
      dic.send(:fill_cold_cache)

      assert_empty(@requests)
    end

    # 🔴 入口（`new`）から通して、上流を引かないこと。
    def test_new_does_not_fetch
      warm_last_good
      dic = create_dictionary([@source])

      assert_equal(entries.keys, dic.keys)
      assert_equal(0, @source.parsed)
      assert_equal(1, @requests.size)
    end

    # ⚠ 更新ワーカー用の `lazy: true` は、依頼も組み立てもしない（直後に自分で `refresh` する）。
    def test_lazy_new_does_nothing
      warm_last_good
      dic = create_dictionary([@source], lazy: true)

      assert_empty(dic)
      assert_empty(@requests)
    end

    # ⚠⚠ 据え置いた回は本体キャッシュの寿命を延ばす（9 件目）。
    def test_retention_extends_ttl
      @dic.refresh
      shorten_ttl(100)
      break_source
      logged = capture_log(@dic) {@dic.refresh}
      retained = logged.find {|v| v[:message] == 'tagging dictionary retained'}

      assert_not_nil(retained)
      assert_true(retained[:ttl_extended])
      assert_operator(ttl, :>, 100)
    end

    # ⚠ 無期限には延ばさない。作ってから `source_ttl`（24 時間）を過ぎた本体は延ばさない。
    def test_retention_does_not_extend_old_cache
      @dic.refresh
      age_payload(TaggingDictionary::DEFAULT_SOURCE_CACHE_TTL + 60)
      break_source
      logged = capture_log(@dic) {@dic.refresh}
      retained = logged.find {|v| v[:message] == 'tagging dictionary retained'}

      assert_false(retained[:ttl_extended])
      assert_operator(ttl, :<=, 100)
    end

    # ⚠ 延ばす先も上限で切る（PR #4830 の Codex P2）。上限まで残り 30 秒なら 30 秒まで。
    def test_retention_extension_is_capped_at_the_horizon
      @dic.refresh
      age_payload(TaggingDictionary::DEFAULT_SOURCE_CACHE_TTL - 30)
      break_source
      logged = capture_log(@dic) {@dic.refresh}
      retained = logged.find {|v| v[:message] == 'tagging dictionary retained'}

      assert_true(retained[:ttl_extended])
      assert_operator(ttl, :<=, 30)
    end

    private

    # 上流が空を返し、last-good も無い（＝埋められない失敗）状態にする。
    def break_source
      @source.words = {}
      redis.keys("#{TaggingDictionary::SOURCE_REDIS_KEY_PREFIX}/*").each {|key| redis.unlink(key)}
    end

    def warm_last_good
      @dic.send(:save_source, @source, entries)
    end

    def shorten_ttl(seconds)
      redis.expire(TaggingDictionary::REDIS_KEY, seconds)
    end

    def ttl
      return redis.remaining_seconds(redis.create_key(TaggingDictionary::REDIS_KEY), 0)
    end

    def age_payload(seconds)
      payload = Marshal.load(redis[TaggingDictionary::REDIS_KEY]) # rubocop:disable Security/MarshalLoad
      payload[:generated_at] = Time.now - seconds
      redis.setex(TaggingDictionary::REDIS_KEY, 100, Marshal.dump(payload))
    end

    def capture_log(dic)
      logged = []
      double = Object.new
      [:info, :error].each do |level|
        double.define_singleton_method(level) {|payload| logged.push(payload)}
      end
      dic.define_singleton_method(:logger) {double}
      yield
      return logged
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def entries(key = 'キュアスタ')
      return {key => {pattern: Regexp.new(key), regexp: key, words: [key]}}
    end

    def handler_double(dics)
      return Struct.new(:all).new(dics.map {|dic| {'url' => dic.uri.to_s}})
    end

    def build_dictionary(dics = [])
      dic = TaggingDictionary.allocate
      dic.instance_variable_set(:@handler, handler_double(dics))
      dic.define_singleton_method(:remote_dictionaries) {dics}
      return dic
    end

    # `initialize` を通す。⚠ `Handler.create(:dictionary_tag)` は DB を触るので差し替える。
    def create_dictionary(dics, **)
      handler = handler_double(dics)
      klass = Class.new(TaggingDictionary) do
        define_method(:remote_dictionaries) {dics}
      end
      original = Handler.method(:create)
      Handler.define_singleton_method(:create) {|*| handler}
      return klass.new(**)
    ensure
      Handler.define_singleton_method(:create, original)
    end
  end
end
