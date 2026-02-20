module Mulukhiya
  class AccessTokenTest < TestCase
    def disable?
      return true unless test_token
      return super
    end

    def setup
      @token = sns_class.new.access_token
    end

    test 'テスト用トークンの有無' do
      assert_not_nil(@token)
    end

    def test_valid?
      return false unless @token

      assert_boolean(@token.valid?)
    end

    def test_webhook_digest
      return unless @token

      assert_kind_of(String, @token.webhook_digest)
      assert_predicate(@token.webhook_digest, :present?)
    end

    def test_to_s
      return unless @token

      assert_kind_of(String, @token.to_s)
      assert_predicate(@token.to_s, :present?)
    end

    def test_token
      return unless @token

      assert_kind_of(String, @token.token)
      assert_predicate(@token.token, :present?)
    end

    def test_to_h
      return unless @token

      assert_kind_of(Hash, @token.to_h)
      assert_kind_of(account_class, @token.to_h[:account])
      assert_kind_of(String, @token.to_h[:digest])
      assert_boolean(@token.to_h[:is_scopes_valid])
      assert_kind_of(Array, @token.to_h[:scopes])
      assert_kind_of(String, @token.to_h[:token])
    end

    def test_account
      return unless @token

      assert_kind_of(account_class, @token.account)
    end

    def test_scopes
      return unless @token

      assert_kind_of(Set, @token.scopes)
    end

    def test_scopes_valid?
      return false unless @token

      assert_predicate(@token, :scopes_valid?)
    end

    def test_webhook_entries
      access_token_class.webhook_entries.first(5).each do |entry|
        assert_kind_of(String, entry[:digest])
        assert_kind_of(String, entry[:token])
        assert_kind_of(account_class, entry[:account])
      end
    end
  end
end
