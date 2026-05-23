require 'securerandom'

module Mulukhiya
  class RateLimitStorageTest < TestCase
    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @storage = RateLimitStorage.new
      @key = "test_#{SecureRandom.hex(8)}"
    end

    def teardown
      return if disable?
      @storage.unlink(@key)
    end

    def test_prefix
      assert_equal('rate_limit', @storage.prefix)
    end

    def test_increment_starts_at_one
      assert_equal(1, @storage.increment(@key, window: 60))
    end

    def test_increment_increases
      @storage.increment(@key, window: 60)
      @storage.increment(@key, window: 60)

      assert_equal(3, @storage.increment(@key, window: 60))
    end

    def test_sha_matches_server_script_load
      loaded = @storage.redis.call('SCRIPT', 'LOAD', RateLimitStorage::INCREMENT_SCRIPT)

      assert_equal(RateLimitStorage::INCREMENT_SCRIPT_SHA, loaded)
    end

    def test_increment_recovers_from_flushed_script_cache
      @storage.increment(@key, window: 60)
      @storage.redis.call('SCRIPT', 'FLUSH')

      assert_equal(2, @storage.increment(@key, window: 60))
    end
  end
end
