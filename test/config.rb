module MulukhiyaTootProxy
  class ConfigTest < Test::Unit::TestCase
    def test_deep_merge
      config = Config.deep_merge({}, {a: 111, b: 222})
      assert_equal(config, {'a' => 111, 'b' => 222})
      config = Config.deep_merge(config, {c: {d: 333, e: 444}})
      assert_equal(config, {'a' => 111, 'b' => 222, 'c' => {'d' => 333, 'e' => 444}})
      config = Config.deep_merge(config, {c: {e: 333, f: 444}})
      assert_equal(config, {'a' => 111, 'b' => 222, 'c' => {'d' => 333, 'e' => 333, 'f' => 444}})
      config = Config.deep_merge(config, {c: {d: nil}})
      assert_equal(config, {'a' => 111, 'b' => 222, 'c' => {'e' => 333, 'f' => 444}})
    end
  end
end
