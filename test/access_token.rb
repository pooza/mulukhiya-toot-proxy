module Mulukhiya
  class AccessTokenTest < TestCase
    def setup
      @token = Environment.sns_class.new.access_token
    end

    def test_valid?
      assert_boolean(@token.valid?)
    end

    def test_webhook_digest
      assert_kind_of(String, @token.webhook_digest)
      assert(@token.webhook_digest.present?)
    end

    def test_to_s
      assert_kind_of(String, @token.to_s)
      assert(@token.to_s.present?)
    end

    def test_token
      assert_kind_of(String, @token.token)
      assert(@token.token.present?)
    end

    def test_to_h
      assert_kind_of(Hash, @token.to_h)
      assert(@token.to_h.key?(:token))
      assert(@token.to_h.key?(:digest))
      assert(@token.to_h.key?(:account))
      assert(@token.to_h.key?(:scopes))
    end

    def test_scopes
      assert_kind_of(Array, @token.scopes)
    end
  end
end
