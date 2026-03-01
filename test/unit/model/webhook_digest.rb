module Mulukhiya
  class WebhookDigestTest < TestCase
    def setup
      @uri = Ginseng::URI.parse('https://example.com')
      @token = 'test_token_for_digest_stability'
    end

    def test_deterministic
      digest1 = Webhook.create_digest(@uri, @token)
      digest2 = Webhook.create_digest(@uri, @token)

      assert_equal(digest1, digest2)
    end

    def test_hex_format
      digest = Webhook.create_digest(@uri, @token)

      assert_match(/\A[0-9a-f]{64}\z/, digest)
    end

    def test_sensitive_to_uri
      digest1 = Webhook.create_digest(@uri, @token)
      digest2 = Webhook.create_digest(Ginseng::URI.parse('https://other.example.com'), @token)

      assert_not_equal(digest1, digest2)
    end

    def test_sensitive_to_token
      digest1 = Webhook.create_digest(@uri, @token)
      digest2 = Webhook.create_digest(@uri, 'different_token')

      assert_not_equal(digest1, digest2)
    end
  end
end
