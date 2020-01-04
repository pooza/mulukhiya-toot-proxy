module MulukhiyaTootProxy
  class RedisTest < TestCase
    def setup
      @redis = Redis.new
    end

    def test_edit
      assert_equal(@redis.set(__dir__, '一兆度の炎'), 'OK')
      assert_equal(@redis.get(__dir__), '一兆度の炎')
      assert_equal(@redis.del(__dir__), 1)
    end
  end
end
