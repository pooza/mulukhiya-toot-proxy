require 'securerandom'

module Mulukhiya
  class IsCatStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = IsCatStorage.new
      @key = "test_#{SecureRandom.hex(8)}@example.com"
    end

    def test_prefix
      assert_equal('is_cat', @storage.prefix)
    end

    def test_ttl
      assert_kind_of(Integer, @storage.ttl)
      assert_operator(@storage.ttl, :>, 0)
    end

    def test_failure_ttl
      assert_kind_of(Integer, @storage.failure_ttl)
      assert_operator(@storage.failure_ttl, :<, @storage.ttl)
    end

    # 取れなかった acct も覚えておく (#4677)。読んだ側は `is_cat` が nil の当たりになる。
    def test_remember_failure
      @storage.remember_failure(@key)
      result = @storage.get(@key)

      assert_kind_of(Hash, result)
      assert_nil(result['is_cat'])
      assert_true(result['failed'])
    ensure
      @storage.unlink(@key)
    end

    def test_get_set
      assert_nil(@storage.get(@key))

      @storage.set(@key, {is_cat: true, acct: @key})
      result = @storage.get(@key)

      assert_kind_of(Hash, result)
      assert(result['is_cat'])

      @storage.unlink(@key)

      assert_nil(@storage.get(@key))
    end
  end
end
