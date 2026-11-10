module Mulukhiya
  # 値を JSON で読み書きするストレージの共通部分 (#4898)。
  #
  # ⚠ 写しの 1 本（`MediaMetadataStorage#get`）は、無い鍵を引くと `supernil`（打ち間違い）と
  # 未定義の `key` で NameError を投げていた。呼ぶ側が `key?` で先に確かめていたので表に出なかった。
  class JSONStorageTest < TestCase
    class PlainStorage < JSONStorage
      def prefix
        return 'json_storage_test'
      end
    end

    class TTLStorage < PlainStorage
      def ttl
        return 60
      end

      def symbolize_names?
        return true
      end

      def default_value
        return {}
      end
    end

    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @key = SecureRandom.hex
      @plain = PlainStorage.new
      @ttl = TTLStorage.new
    end

    def teardown
      @plain&.unlink(@key)
      @ttl&.unlink(@key)
      super
    end

    def test_round_trip
      return if disable?
      @plain.set(@key, {'a' => [1, {'b' => 2}]})

      assert_equal({'a' => [1, {'b' => 2}]}, @plain.get(@key))
      assert_equal(-1, @plain.redis.call('TTL', @plain.create_key(@key)))
    end

    def test_ttl_and_symbolize
      return if disable?
      @ttl.set(@key, {'a' => [{'b' => 2}]})

      assert_equal({a: [{b: 2}]}, @ttl.get(@key))
      assert_predicate(@ttl.redis.call('TTL', @ttl.create_key(@key)), :positive?)
    end

    def test_explicit_ttl
      return if disable?
      @plain.set(@key, {}, ttl: 30)

      assert_predicate(@plain.redis.call('TTL', @plain.create_key(@key)), :positive?)
    end

    def test_missing_returns_default
      return if disable?

      assert_nil(@plain.get(@key))
      assert_empty(@ttl.get(@key))
    end

    def test_broken_value_returns_default
      return if disable?
      @plain.redis.call('SET', @plain.create_key(@key), '{broken')

      assert_nil(@plain.get(@key))
    end

    def test_media_metadata_missing_returns_nil
      return if disable?

      assert_nil(MediaMetadataStorage.new.get(Ginseng::URI.parse("https://media.test/#{@key}.jpg")))
    end
  end
end
