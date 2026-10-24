module Mulukhiya
  # `AccessTokenMethods#to_h`（`GET /config` が返す）。⚠ DB に繋がない。
  class AccessTokenMethodsTest < TestCase
    class FakeToken
      include AccessTokenMethods

      def values
        return {id: 1, token: 'access', refresh_token: 'refresh', previous_refresh_token: 'old'}
      end

      def account = nil
      def webhook_digest = 'digest'
      def scopes_valid? = true
      def scopes = Set['read']
      def to_s = 'access'
    end

    # ⚠⚠ 更新用のトークンを出さない（PR #4844 の Codex P1）。出すと、アクセストークンを
    # 持つだけで期限切れの後も新しいトークンを作れる。
    def test_to_h_excludes_refresh_tokens
      hash = FakeToken.new.to_h

      assert_false(hash.key?(:refresh_token))
      assert_false(hash.key?(:previous_refresh_token))
      assert_equal('access', hash[:token])
      assert_equal(['read'], hash[:scopes])
    end
  end
end
