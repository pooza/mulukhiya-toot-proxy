module Mulukhiya
  class QueryTemplateTest < TestCase
    def setup
      @template = QueryTemplate.new('token_owner')
    end

    def test_create_sql
      @template.params = {token: %(longlong'token')}
      assert_equal(@template.to_s, %{SELECT accounts.id FROM oauth_access_tokens AS tokens INNER JOIN users ON tokens.resource_owner_id=users.id INNER JOIN accounts ON users.account_id=accounts.id WHERE (accounts.domain IS NULL) AND (accounts.silenced_at IS NULL) AND (accounts.suspended_at IS NULL) AND (users.disabled='f') AND (tokens.expires_in IS NULL) AND (tokens.revoked_at IS NULL) AND (tokens.token='longlong''token''')})
    end
  end
end
