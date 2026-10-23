module Mulukhiya
  # `IsCatStorage` は読み書きとも再送しない（5.43.0 のリリース前レビュー）。
  #
  # ⚠ Redis の障害中に ginseng-redis の再送（1 回あたり約 2 秒）を acct ごとに踏むと、
  # `POST /account/is_cat` が 5 秒を超える。本物の Redis を落とせないのでダブルで数える。
  class IsCatStorageNoRetryTest < TestCase
    def setup
      @storage = IsCatStorage.new
      @calls = calls = []
      redis = Object.new
      redis.define_singleton_method(:call) do |*args|
        calls.push(args.first)
        raise RedisClient::CannotConnectError, 'Connection refused'
      end
      @storage.define_singleton_method(:redis) {redis}
    end

    def test_get_does_not_retry
      assert_nil(@storage.get('someone@example.com'))
      assert_equal(['GET'], @calls)
    end

    def test_set_does_not_retry
      assert_nothing_raised do
        @storage.set('someone@example.com', {is_cat: true})
      end
      assert_equal(['SET'], @calls)
    end

    def test_remember_failure_does_not_retry
      assert_nothing_raised do
        @storage.remember_failure('someone@example.com')
      end
      assert_equal(['SET'], @calls)
    end
  end
end
