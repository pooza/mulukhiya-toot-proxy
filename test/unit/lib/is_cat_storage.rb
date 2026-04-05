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
