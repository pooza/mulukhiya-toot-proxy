module MulukhiyaTootProxy
  class PostgresTest < Test::Unit::TestCase
    def setup
      @db = Postgres.instance
    end

    def test_escape_string
      assert_equal(@db.escape_string('あえ'), 'あえ')
      assert_equal(@db.escape_string(%(あえ")), %(あえ\"))
      assert_equal(@db.escape_string(%(あえ')), %(あえ''))
    end

    def test_create_sql
      assert_equal(@db.create_sql('token_owner', {token: '40c547ba8d383345002ecff58ae5e45e57631d42a3b4b65f817b2d8a558b6116'}), %!SELECT resource_owner_id FROM oauth_access_tokens WHERE (token='40c547ba8d383345002ecff58ae5e45e57631d42a3b4b65f817b2d8a558b6116');!)
    end
  end
end
