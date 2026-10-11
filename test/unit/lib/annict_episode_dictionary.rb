module Mulukhiya
  # Annict のエピソード辞書が、Annict の不調を前回の結果で凌ぐこと (#4801)。
  class AnnictEpisodeDictionaryTest < TestCase
    FRESH = 600
    ALERT = 21_600
    CACHED = {'前回のサブタイトル' => ['1話']}.freeze

    # Redis を使わないストレージのダブル。`updated_at` を好きな古さで置ける。
    class StorageDouble
      attr_reader :writes, :alerts, :cleared

      def initialize(entries: nil, age: 0, writable: true)
        @value = {'entries' => entries, 'updated_at' => Time.now.to_i - age} if entries
        @writable = writable
        @writes = []
        @alerts = 0
        @cleared = 0
      end

      # 1 回目だけ true（印を置けた）。
      def first_alert?(_seconds)
        @alerts += 1
        return @alerts == 1
      end

      def clear_alert
        @cleared += 1
      end

      def get(_key)
        return @value
      end

      def set(_key, entries)
        @writes.push(entries)
        return @writable
      end
    end

    class AnnictDouble
      attr_reader :calls

      def initialize(episodes: [], error: nil, works: [{'annictId' => 1}])
        @episodes = episodes
        @error = error
        @works = works
        @calls = 0
      end

      def works
        @calls += 1
        raise @error if @error
        return @works
      end

      def episodes(_ids)
        return @episodes
      end
    end

    EPISODES = [
      {'title' => ' ふたりのプリキュア ', 'numberText' => '第23話'},
      {'title' => '最終話', 'numberText' => nil},
      {'title' => '', 'numberText' => '第1話'},
    ].freeze
    BUILT = {'ふたりのプリキュア' => ['23話'], '最終話' => []}.freeze

    def setup
      @saved = ['fresh', 'alert'].to_h {|k| [k, config["/service/annict/dictionary/cache/#{k}"]]}
      config['/service/annict/dictionary/cache/fresh'] = FRESH
      config['/service/annict/dictionary/cache/alert'] = ALERT
    end

    def teardown
      @saved.each {|k, v| config["/service/annict/dictionary/cache/#{k}"] = v}
    end

    def test_builds_and_stores_without_cache
      storage = StorageDouble.new
      dictionary = create(AnnictDouble.new(episodes: EPISODES), storage)

      assert_equal(BUILT, dictionary.fetch)
      assert_equal([BUILT], storage.writes)
      assert_nil(dictionary.error)
      assert_false(dictionary.alert?)
    end

    # 新しいうちは Annict を引かない。
    def test_fresh_cache_skips_annict
      annict = AnnictDouble.new(episodes: EPISODES)
      storage = StorageDouble.new(entries: CACHED, age: FRESH - 60)
      dictionary = create(annict, storage)

      assert_equal(CACHED, dictionary.fetch)
      assert_equal(0, annict.calls)
      assert_empty(storage.writes)
    end

    def test_stale_cache_is_refreshed
      annict = AnnictDouble.new(episodes: EPISODES)
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)
      dictionary = create(annict, storage)

      assert_equal(BUILT, dictionary.fetch)
      assert_equal(1, annict.calls)
      assert_equal([BUILT], storage.writes)
    end

    # 🔴 本件の芯: Annict が落ちても前回の結果を返し、鳴らさない。
    def test_gateway_error_falls_back_quietly
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)
      dictionary = create(AnnictDouble.new(error: Ginseng::GatewayError.new('Net::ReadTimeout')), storage)

      assert_equal(CACHED, dictionary.fetch)
      assert_kind_of(Ginseng::GatewayError, dictionary.error)
      assert_false(dictionary.alert?)
      assert_empty(storage.writes)
    end

    # ⚠ 古い結果で凌げなくなってきたら鳴らす（返すこと自体は続ける）。
    def test_gateway_error_alerts_when_cache_is_too_old
      storage = StorageDouble.new(entries: CACHED, age: ALERT + 60)
      dictionary = create(AnnictDouble.new(error: Ginseng::GatewayError.new('Net::ReadTimeout')), storage)

      assert_equal(CACHED, dictionary.fetch)
      assert_predicate(dictionary, :alert?)
    end

    # ⚠ 返せる結果が無いときは、従来どおり上流のエラーを上げる。
    # 🔴 6 時間を超えた障害でも、アラートは 1 回だけ（5.40.0 のリリース前レビュー）。辞書は 10 分おきに
    # 引かれるので、古さだけで判定すると取得のたびに鳴る。
    def test_gateway_error_alerts_once_per_outage
      storage = StorageDouble.new(entries: CACHED, age: ALERT + 60)
      annict = AnnictDouble.new(error: Ginseng::GatewayError.new('Net::ReadTimeout'))
      first = create(annict, storage)
      second = create(annict, storage)

      assert_equal(CACHED, first.fetch)
      assert_predicate(first, :alert?)
      assert_equal(CACHED, second.fetch)
      assert_not_predicate(second, :alert?)
      assert_not_nil(second.error)
    end

    # ⚠ 取得に成功したら印を消す（次の障害でまた 1 回鳴らす）。
    def test_success_clears_the_alert_mark
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)

      assert_equal(BUILT, create(AnnictDouble.new(episodes: EPISODES), storage).fetch)
      assert_equal(1, storage.cleared)
    end

    # 🔴 空の結果で、中身のあるキャッシュを上書きしない（5.40.0 のリリース前レビュー）。Annict は不調のとき
    # 200 で空の検索結果を返すことがあり、そのまま書くと「凌ぐための結果」が空になる。
    def test_empty_result_does_not_overwrite_cache
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)
      dictionary = create(AnnictDouble.new(episodes: []), storage)

      assert_equal(CACHED, dictionary.fetch)
      assert_empty(storage.writes)
      assert_not_predicate(dictionary, :alert?)
    end

    # ⚠ 見る作品が 0 件（キーワードを外した）なら、空が正しい答え。キャッシュを空で置き換える
    # （PR #4819 の Codex P2）。
    def test_empty_result_without_works_replaces_cache
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)

      assert_empty(create(AnnictDouble.new(episodes: [], works: []), storage).fetch)
      assert_equal([{}], storage.writes)
    end

    # ⚠ キャッシュが無ければ、空もそのまま書く。
    def test_empty_result_is_stored_without_cache
      storage = StorageDouble.new

      assert_empty(create(AnnictDouble.new(episodes: []), storage).fetch)
      assert_equal([{}], storage.writes)
    end

    def test_error_is_raised_without_cache
      dictionary = create(AnnictDouble.new(error: Ginseng::GatewayError.new('Net::ReadTimeout')), StorageDouble.new)

      assert_raise(Ginseng::GatewayError) {dictionary.fetch}
    end

    # ⚠ 上流の失敗ではないもの（こちらのバグ）は、凌げていても鳴らす。
    def test_unexpected_error_alerts_even_with_cache
      storage = StorageDouble.new(entries: CACHED, age: FRESH + 60)
      dictionary = create(AnnictDouble.new(error: NoMethodError.new('undefined method')), storage)

      assert_equal(CACHED, dictionary.fetch)
      assert_predicate(dictionary, :alert?)
    end

    # ⚠ キャッシュへ書けなくても、取れた結果は返す。
    def test_unwritable_storage_does_not_break_the_response
      dictionary = create(AnnictDouble.new(episodes: EPISODES), StorageDouble.new(writable: false))

      assert_equal(BUILT, dictionary.fetch)
      assert_nil(dictionary.error)
    end

    # ⚠ 実物の Redis を通す（ダブルだけだと、保存の形と読み戻しの食い違いを見ない）。
    def test_round_trip_through_redis
      omit('Redis unavailable') unless Redis.health[:status] == 'OK'
      storage = AnnictDictionaryStorage.new
      storage.unlink(AnnictEpisodeDictionary::KEY)

      assert_equal(BUILT, create(AnnictDouble.new(episodes: EPISODES), storage).fetch)

      failing = AnnictDouble.new(error: Ginseng::GatewayError.new('Net::ReadTimeout'))
      config['/service/annict/dictionary/cache/fresh'] = 0
      dictionary = create(failing, storage)

      assert_equal(BUILT, dictionary.fetch)
      assert_equal(1, failing.calls)
      assert_false(dictionary.alert?)
      assert_operator(storage.ttl, :>, ALERT)
    ensure
      storage&.unlink(AnnictEpisodeDictionary::KEY)
    end

    def test_broken_cache_entry_is_ignored
      omit('Redis unavailable') unless Redis.health[:status] == 'OK'
      storage = AnnictDictionaryStorage.new
      storage.setex(AnnictEpisodeDictionary::KEY, 60, 'not json')

      assert_nil(storage.get(AnnictEpisodeDictionary::KEY))

      storage.setex(AnnictEpisodeDictionary::KEY, 60, {entries: []}.to_json)

      assert_nil(storage.get(AnnictEpisodeDictionary::KEY))
    ensure
      storage&.unlink(AnnictEpisodeDictionary::KEY)
    end

    # ルートが新しいクラスを通っていること（素の呼び出しへ戻ると、凌げなくなる）。
    def test_route_uses_the_dictionary
      source = File.read(File.join(Environment.dir, 'app/lib/mulukhiya/controller/api_controller.rb'))
      route = source[%r{get '/tagging/dic/annict/episodes' do.*?\n    end\n}m]

      assert_match(/AnnictEpisodeDictionary\.new\(annict\)/, route)
      assert_match(/report_error\(dictionary\.error\) if dictionary\.alert\?/, route)
    end

    private

    def create(annict, storage)
      return AnnictEpisodeDictionary.new(annict, storage:)
    end
  end
end
