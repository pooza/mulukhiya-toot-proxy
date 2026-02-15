module Mulukhiya
  class OAuthHelperTest < TestCase
    def test_generate_code_verifier
      verifier = OAuthHelper.generate_code_verifier

      assert_kind_of(String, verifier)
      assert_operator(verifier.length, :>=, 43)
      assert_operator(verifier.length, :<=, 128)
    end

    def test_generate_code_challenge
      verifier = OAuthHelper.generate_code_verifier
      challenge = OAuthHelper.generate_code_challenge(verifier)

      assert_kind_of(String, challenge)
      assert_predicate(challenge, :present?)
      assert_not_equal(verifier, challenge)

      expected = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)

      assert_equal(expected, challenge)
    end

    def test_generate_state
      state1 = OAuthHelper.generate_state
      state2 = OAuthHelper.generate_state

      assert_kind_of(String, state1)
      assert_predicate(state1, :present?)
      assert_not_equal(state1, state2)
    end

    def test_create_and_consume_oauth_state
      result = OAuthHelper.create_oauth_state(sns_type: 'mastodon')

      assert_kind_of(Hash, result)
      assert_predicate(result[:state], :present?)
      assert_predicate(result[:code_challenge], :present?)

      consumed = OAuthHelper.consume_oauth_state(result[:state])

      assert_kind_of(Hash, consumed)
      assert_predicate(consumed[:code_verifier], :present?)
      assert_equal('mastodon', consumed[:sns_type])
    end

    def test_consume_oauth_state_one_time
      result = OAuthHelper.create_oauth_state(sns_type: 'misskey')
      consumed = OAuthHelper.consume_oauth_state(result[:state])

      assert_not_nil(consumed)

      consumed_again = OAuthHelper.consume_oauth_state(result[:state])

      assert_nil(consumed_again)
    end

    def test_consume_oauth_state_invalid
      consumed = OAuthHelper.consume_oauth_state('invalid_state_value')

      assert_nil(consumed)
    end
  end
end
