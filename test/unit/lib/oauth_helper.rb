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

    # 🔴 **読み出しと削除が原子的であること（PR #4714 の Codex P2）。**
    # ⚠⚠ `get` → `unlink` の 2 段だと、**同じ state を使った同時アクセスが
    # 両方とも通る**。`GETDEL` で 1 コマンドにしてある。
    def test_consume_is_atomic
      result = OAuthHelper.create_oauth_state(sns_type: 'mastodon')
      winners = Concurrent::Array.new

      threads = Array.new(8) do
        Thread.new {winners.push(OAuthHelper.consume_oauth_state(result[:state]))}
      end
      threads.each(&:join)

      assert_equal(1, winners.compact.length, '同じ state で複数回通っている')
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

    # 🔴 **PKCE の callback は `code_verifier` を持たない state を拒む。**
    # ⚠⚠ 同じストアに Spotify の state（`{service:, account_id:}`・#4414）も入る。
    # 有無だけ見ると **`code_verifier` が nil のままトークン交換へ進み**、PKCE の束縛が
    # 効かない（5.37.0 リリース前レビュー・#4726 の関連）。
    def test_pkce_rejects_a_state_without_code_verifier
      state = OAuthHelper.generate_state
      OAuthHelper.storage.set(state, {service: 'spotify', account_id: 1})

      assert_raises(Ginseng::AuthError) {pkce_service.auth_with_pkce('code', state)}
    end

    # 自分で発行した state は通る（機能を殺していない）。
    def test_pkce_accepts_its_own_state
      result = OAuthHelper.create_oauth_state(sns_type: 'mastodon')

      assert_equal(:exchanged, pkce_service.auth_with_pkce('code', result[:state]))
    end

    private

    # ⚠ `allocate` で作る（`new` は SNS への接続設定を読む）。見たいのは state の
    # 検査だけなので、トークン交換と callback URI は差し替える。
    def pkce_service
      service = MastodonService.allocate
      service.define_singleton_method(:oauth_token_request) {|*, **| :exchanged}
      service.define_singleton_method(:oauth_callback_uri) {'https://example.com/mulukhiya/oauth/callback'}
      return service
    end
  end
end
