module Mulukhiya
  # Annict のエピソード辞書が、Annict の不調を前回の結果で凌ぐこと (#4801)。
  class AnnictEpisodeDictionaryTest < TestCase
    FRESH = 600
    ALERT = 21_600
    CACHED = {'前回のサブタイトル' => ['1話']}.freeze

    # Redis を使わないストレージのダブル。`updated_at` を好きな古さで置ける。
    class StorageDouble
      attr_reader :writes

      def initialize(entries: nil, age: 0, writable: true)
        @value = {'entries' => entries, 'updated_at' => Time.now.to_i - age} if entries
        @writable = writable
        @writes = []
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

      def initialize(episodes: [], error: nil)
        @episodes = episodes
        @error = error
        @calls = 0
      end

      def works
        @calls += 1
        raise @error if @error
        return [{'annictId' => 1}]
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
      config['/service/annict/dictionary/cache/fresh'] = FRESH
      config['/service/annict/dictionary/cache/alert'] = ALERT
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
