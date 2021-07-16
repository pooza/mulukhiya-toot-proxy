module Mulukhiya
  class AccessTokenTest < TestCase
    def setup
      @token = sns_class.new.access_token
    end

    test 'テスト用トークンの有無' do
      assert(@token)
    end

    def test_valid?
      return unless @token
      assert_boolean(@token.valid?)
    end

    def test_webhook_digest
      return unless @token
      assert_kind_of(String, @token.webhook_digest)
      assert(@token.webhook_digest.present?)
    end

    def test_to_s
      return unless @token
      assert_kind_of(String, @token.to_s)
      assert(@token.to_s.present?)
    end

    def test_token
      return unless @token
      assert_kind_of(String, @token.token)
      assert(@token.token.present?)
    end

    def test_to_h
      return unless @token
      assert_kind_of(Hash, @token.to_h)
      assert(@token.to_h.key?(:token))
      assert(@token.to_h.key?(:digest))
      assert(@token.to_h.key?(:account))
      assert(@token.to_h.key?(:scopes))
    end

    def test_scopes
      return unless @token
      assert_kind_of(Array, @token.scopes)
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
