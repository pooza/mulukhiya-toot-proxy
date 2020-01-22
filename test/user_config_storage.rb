require 'securerandom'

module Mulukhiya
  class UserConfigStorageTest < TestCase
    def setup
      @storage = UserConfigStorage.new
      @key = SecureRandom.hex(16)
    end

    def test_edit
      @storage.update(@key, {a: 111, b: 222})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222})

      @storage.update(@key, {c: {d: 'hoge', e: 'gebo'}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/c/d' => 'hoge', '/c/e' => 'gebo'})

      @storage.update(@key, {c: {e: 'fuga', f: 'fugafuga'}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/c/d' => 'hoge', '/c/e' => 'fuga', '/c/f' => 'fugafuga'})

      @storage.update(@key, {c: {d: nil}})
      assert_equal(@storage[@key], {'/a' => 111, '/b' => 222, '/c/e' => 'fuga', '/c/f' => 'fugafuga'})

      @storage.del(@key)
    end
  end
end
