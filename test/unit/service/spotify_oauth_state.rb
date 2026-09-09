module Mulukhiya
  # Spotify OAuth の `state`（CSRF 対策）(#4414)。
  #
  # ⚠ 初版は「ユーザー特定は SNS トークンで行うため `state` は不要」と判断して
  # 省いていた。`state` は**認可レスポンスの取り違え・横取り**への対策で、
  # ユーザー特定とは別の軸。
  class SpotifyOAuthStateTest < TestCase
    def setup
      @service = SpotifyUserService.allocate
    end

    # 🔴 **本体。**`oauth_uri` が毎回新しい `state` を発行し、URI に載せる。
    def test_oauth_uri_carries_a_fresh_state
      omit('Spotify の client_id が未設定') unless SpotifyUserService.config?

      first = state_of(SpotifyUserService.new.oauth_uri)
      second = state_of(SpotifyUserService.new.oauth_uri)

      assert_predicate(first, :present?, 'state が付いていない')
      assert_not_equal(first, second, '毎回同じ state を返している')
    end

    # 🔴 **発行した state は通る。**
    def test_issued_state_verifies
      state = @service.send(:create_state)

      assert_nothing_raised {@service.send(:verify_state!, state)}
    end

    # 🔴 **一度きり。**`consume` が読み出しと同時に消すのでリプレイできない。
    def test_state_is_single_use
      state = @service.send(:create_state)
      @service.send(:verify_state!, state)

      assert_raises(Ginseng::AuthError) {@service.send(:verify_state!, state)}
    end

    # 🔴 **知らない state は拒否。**
    def test_unknown_state_is_rejected
      assert_raises(Ginseng::AuthError) {@service.send(:verify_state!, 'not-issued-here')}
    end

    # ⚠ 空・nil も拒否（**「無ければ素通し」にしない**）。
    def test_blank_state_is_rejected
      [nil, '', '   '].each do |value|
        assert_raises(Ginseng::AuthError, "#{value.inspect} が素通しした") do
          @service.send(:verify_state!, value)
        end
      end
    end

    # 🔴 **他系統の state を使い回せない。**
    # ⚠⚠ `OAuthStateStorage` は Mastodon / Misskey の PKCE フローと**同じストア**。
    # 印を見ないと、あちらで発行した state が Spotify の認可に通ってしまう。
    def test_state_from_another_flow_is_rejected
      foreign = OAuthHelper.create_oauth_state(sns_type: 'mastodon')

      assert_raises(Ginseng::AuthError) {@service.send(:verify_state!, foreign[:state])}
    end

    # ⚠ 契約側でも必須にしてあること（ルートへ届く前に 422 で落とす）。
    def test_contract_requires_state
      errors = SpotifyAuthContract.new.exec({code: 'abc'})

      assert(errors.key?(:state), 'contract が state を必須にしていない')
    end

    private

    def state_of(uri)
      return Ginseng::URI.parse(uri.to_s).query_values['state']
    end
  end
end
