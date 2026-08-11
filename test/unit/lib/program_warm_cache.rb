module Mulukhiya
  # 読み経路のキャッシュ温めが既存の値を上書きしないこと (#4575)。
  #
  # ⚠ 本物の `program` キーは触らない。ProgramFetcher::REDIS_KEY を書くと、
  # 番組表を持つ環境で実データのキャッシュを壊す（ProgramWriteLockTest が
  # var/program.yaml も Redis も触らない方針にしているのと同じ理由）。
  class ProgramWarmCacheTest < TestCase
    KEY = 'test:program_warm_cache'.freeze

    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @redis = Redis.new
      @redis.unlink(KEY)
    end

    def teardown
      return if disable?
      @redis&.unlink(KEY)
      super
    end

    def test_setnx_sets_when_absent
      return if disable?

      assert_true(@redis.setnx(KEY, 'v1'))
      assert_equal('v1', @redis[KEY])
    end

    # ここが本題。無条件 SET だと、古い内容を読んだ読み手が、その後に完走した
    # 書き手の新しい値を上書きできる。
    def test_setnx_does_not_overwrite
      return if disable?
      @redis.setnx(KEY, 'v1')

      assert_false(@redis.setnx(KEY, 'v2'))
      assert_equal('v1', @redis[KEY])
    end

    # 書き経路（update_cache）は無条件 SET のままであること。読みだけ NX に
    # したつもりが両方 NX になると、編集がキャッシュへ反映されなくなる。
    def test_plain_set_still_overwrites
      return if disable?
      @redis.setnx(KEY, 'v1')
      @redis[KEY] = 'v2'

      assert_equal('v2', @redis[KEY])
    end

    # ProgramFetcher の読み経路が setnx を通ること。⚠ ここが []= に戻ると
    # 「書き手 × 読み手」の lost update が黙って復活する。
    def test_warm_cache_uses_setnx
      return if disable?
      called = []
      fetcher = ProgramFetcher.new
      double = Object.new
      double.define_singleton_method(:setnx) do |key, value|
        called.push([:setnx, key, value])
        next true
      end
      double.define_singleton_method(:[]=) {|key, value| called.push([:set, key, value])}
      fetcher.define_singleton_method(:redis) {double}

      fetcher.send(:warm_cache, {'x' => {'series' => 'y'}})

      assert_equal(1, called.count)
      assert_equal(:setnx, called.first.first)
      assert_equal(ProgramFetcher::REDIS_KEY, called.first[1])
    end

    # 温めの失敗は無害（次の read が YAML へ倒れる）なので、例外を上げず false。
    def test_warm_cache_swallows_error
      return if disable?
      fetcher = ProgramFetcher.new
      double = Object.new
      double.define_singleton_method(:setnx) {|_key, _value| raise Ginseng::Redis::Error, 'boom'}
      fetcher.define_singleton_method(:redis) {double}

      assert_false(fetcher.send(:warm_cache, {}))
    end
  end
end
