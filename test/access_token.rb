module Mulukhiya
  class AccessTokenTest < TestCase
    def setup
      @token = sns_class.new.access_token
    end

    test 'テスト用トークンの有無' do
      assert_not_nil(@token)
    end

    def test_valid?
      skip unless @token

      assert_boolean(@token.valid?)
    end

    def test_webhook_digest
      skip unless @token

      assert_kind_of(String, @token.webhook_digest)
      assert_predicate(@token.webhook_digest, :present?)
    end

    def test_to_s
      skip unless @token

      assert_kind_of(String, @token.to_s)
      assert_predicate(@token.to_s, :present?)
    end

    def test_token
      skip unless @token

      assert_kind_of(String, @token.token)
      assert_predicate(@token.token, :present?)
    end

    def test_to_h
      skip unless @token

      assert_kind_of(Hash, @token.to_h)
      assert_kind_of(account_class, @token.to_h[:account])
      assert_kind_of(String, @token.to_h[:digest])
      assert_boolean(@token.to_h[:is_scopes_valid])
      assert_kind_of(Array, @token.to_h[:scopes])
      assert_kind_of(String, @token.to_h[:token])
    end

    def test_account
      skip unless @token

      assert_kind_of(account_class, @token.account)
    end

    def test_scopes
      skip unless @token

      assert_kind_of(Set, @token.scopes)
    end

    def test_scopes_valid?
      skip unless @token

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
