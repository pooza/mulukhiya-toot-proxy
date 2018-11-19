require 'securerandom'

module MulukhiyaTootProxy
  class UserConfigStorageTest < Test::Unit::TestCase
    def test_all
      storage = UserConfigStorage.new
      key = SecureRandom.hex(16)
      storage[key] = {a: 111, b: 222}
      assert_equal(storage[key], {'a' => 111, 'b' => 222})
      storage.update(key, {c: 'hoge'})
      assert_equal(storage[key], {'a' => 111, 'b' => 222, 'c' => 'hoge'})
      storage.del(key)
    end
  end
end
