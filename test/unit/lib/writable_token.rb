module Mulukhiya
  # トークンが書き込みのスコープを持つかの判定 (#4845)。⚠ DB に繋がない。
  class WritableTokenTest < TestCase
    class FakeToken
      include AccessTokenMethods

      def initialize(scopes)
        @scopes = scopes
      end

      def scopes
        raise Ginseng::GatewayError, 'Invalid scopes' if @scopes.nil?
        return @scopes.to_set
      end
    end

    def test_writable
      assert_predicate(FakeToken.new(['read', 'write', 'follow', 'push']), :writable?)
      assert_predicate(FakeToken.new(['read', 'write:statuses', 'write:media']), :writable?)
      assert_predicate(FakeToken.new(['write:notes', 'read:account']), :writable?)
      assert_false(FakeToken.new(['read']).writable?)
      assert_false(FakeToken.new(['read:accounts', 'profile']).writable?)
      assert_false(FakeToken.new(['admin:read']).writable?)
      assert_false(FakeToken.new([]).writable?)
    end

    # スコープが読めないときは持たないとみなす。
    def test_unreadable_scopes
      assert_false(FakeToken.new(nil).writable?)
    end

    def test_writable_token_via_access_token
      sns = service(access_token: FakeToken.new(['write']))

      assert_predicate(sns, :writable_token?)
      assert_false(service(access_token: FakeToken.new(['read'])).writable_token?)
    end

    # Misskey の本人のトークンは `access_token` の行を持たない。
    def test_writable_token_via_native_token
      account = Object.new
      account.define_singleton_method(:native_token?) {|token| token == 'native'}

      assert_predicate(service(account:, token: 'native'), :writable_token?)
      assert_false(service(account:, token: 'other').writable_token?)
    end

    # 引けなかったときは使わせない。
    def test_unresolved_token
      assert_false(service.writable_token?)
    end

    # ⚠ gem の `token=` は `@account` しか捨てない。
    def test_token_setter_drops_access_token
      sns = MastodonService.allocate
      sns.instance_variable_set(:@access_token, FakeToken.new(['write']))
      sns.token = nil

      assert_nil(sns.instance_variable_get(:@access_token))
    end

    private

    def service(access_token: nil, account: nil, token: nil)
      sns = MastodonService.allocate
      sns.define_singleton_method(:access_token) {access_token}
      sns.define_singleton_method(:account) {account}
      sns.define_singleton_method(:token) {token}
      return sns
    end
  end
end
