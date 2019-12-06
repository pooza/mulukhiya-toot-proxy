module MulukhiyaTootProxy
  class QueryTemplateTest < Test::Unit::TestCase
    def setup
      @template = QueryTemplate.new('token_owner')
    end

    def test_create_sql
      return unless Postgres.config?

      @template.params = {token: %(longlong'token')}
      assert_equal(@template.to_s, %{SELECT accounts.id, accounts.username, accounts.display_name, accounts.actor_type, users.admin, users.moderator, accounts.locked FROM oauth_access_tokens AS tokens INNER JOIN users ON tokens.resource_owner_id=users.id INNER JOIN accounts ON users.account_id=accounts.id WHERE (accounts.domain IS NULL) AND (accounts.silenced_at IS NULL) AND (accounts.suspended_at IS NULL) AND (users.disabled='f') AND (tokens.expires_in IS NULL) AND (tokens.revoked_at IS NULL) AND (tokens.token='longlong''token''')})
    end
  end
end
