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
      assert_equal(@db.create_sql('token_owner', {token: '40c547ba8d383345002ecff58ae5e45e57631d42a3b4b65f817b2d8a558b6116'}), %!SELECT accounts.id, accounts.username, accounts.display_name, users.admin, users.moderator, accounts.locked FROM oauth_access_tokens AS tokens INNER JOIN accounts ON tokens.resource_owner_id=accounts.id LEFT JOIN users ON accounts.id=users.account_id WHERE (accounts.domain IS NULL) AND (accounts.silenced='f') AND (accounts.suspended='f') AND (users.disabled='f') AND (tokens.token='40c547ba8d383345002ecff58ae5e45e57631d42a3b4b65f817b2d8a558b6116');!)
    end
  end
end
