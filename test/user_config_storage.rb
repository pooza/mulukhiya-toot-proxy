require 'securerandom'

module Mulukhiya
  class UserConfigStorageTest < TestCase
    def setup
      @storage = UserConfigStorage.new
      @key = SecureRandom.hex(16)
    end

    def test_edit
      assert_equal(@storage[@key], {})
      assert_equal(@storage.get(@key), '{}')

      @storage.update(@key, {'a' => 111, 'b' => 222})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222})

      @storage.update(@key, {'cc' => {'d' => 'hoge', 'e' => 'gebo'}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/cc/d' => 'hoge', '/cc/e' => 'gebo'})

      @storage.update(@key, {'cc' => {'e' => 'fuga', 'f' => 'fugafuga'}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/cc/d' => 'hoge', '/cc/e' => 'fuga', '/cc/f' => 'fugafuga'})

      @storage.update(@key, {'cc' => {'d' => nil}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/cc/e' => 'fuga', '/cc/f' => 'fugafuga'})

      @storage.del(@key)
    end
  end
end
