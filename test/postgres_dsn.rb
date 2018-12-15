module MulukhiyaTootProxy
  class PostgresDSNTest < Test::Unit::TestCase
    def setup
      @dsn = PostgresDSN.parse('postgres://postgres:nice_password@localhost:5432/mastodon')
    end

    def test_new
      assert_true(@dsn.is_a?(PostgresDSN))
    end

    def test_scheme
      assert_equal(@dsn.scheme, 'postgres')
    end

    def test_host
      assert_equal(@dsn.host, 'localhost')
    end

    def test_port
      assert_equal(@dsn.port, 5432)
    end

    def test_dbname
      assert_equal(@dsn.dbname, 'mastodon')
    end

    def test_user
      assert_equal(@dsn.user, 'postgres')
    end

    def test_password
      assert_equal(@dsn.password, 'nice_password')
    end

    def test_to_h
      assert_equal(@dsn.to_h, {
        host: 'localhost',
        user: 'postgres',
        password: 'nice_password',
        dbname: 'mastodon',
        port: 5432,
      })
    end
  end
end
