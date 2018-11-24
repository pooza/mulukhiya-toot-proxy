module MulukhiyaTootProxy
  class RedisDSNTest < Test::Unit::TestCase
    def setup
      @dsn = RedisDSN.parse('redis://localhost:6379/1')
    end

    def test_new
      assert_true(@dsn.is_a?(RedisDSN))
    end

    def test_scheme
      assert_equal(@dsn.scheme, 'redis')
    end

    def test_host
      assert_equal(@dsn.host, 'localhost')
    end

    def test_port
      assert_equal(@dsn.port, 6379)
    end

    def test_db
      assert_equal(@dsn.db, 1)
    end
  end
end
