module Mulukhiya
  # Spotify OAuth の `state`（CSRF 対策）(#4414)。
  #
  # ⚠ 初版は「ユーザー特定は SNS トークンで行うため `state` は不要」と判断して
  # 省いていた。`state` は**認可レスポンスの取り違え・横取り**への対策で、
  # ユーザー特定とは別の軸。
  class SpotifyOAuthStateTest < TestCase
    ACCOUNT_ID = 4414

    def setup
      @service = service_for(ACCOUNT_ID)
    end

    # 🔴 **本体。**`oauth_uri` が毎回新しい `state` を発行し、URI に載せる。
    #
    # ⚠ **`omit` しない (#4503)。**`client_id` は本番でも未設定なので、素直に書くと
    # **CI でも実機でも一生実行されないテスト**になる（omission 上限のガードに
    # 実際に引っかかった）。設定に依存する部分だけ差し替えて、**必ず走らせる**。
    def test_oauth_uri_carries_a_fresh_state
      first = state_of(stubbed_service.oauth_uri)
      second = state_of(stubbed_service.oauth_uri)

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

    # 🔴 **発行したアカウント以外では使えない（PR #4714 の Codex P1）。**
    # ⚠⚠ 縛らないと、**攻撃者が自分の Spotify を認可して得た code/state の組を
    # 被害者の callback へ流し込め、攻撃者のトークンが被害者の `UserConfig` に入る**
    # （セッション固定と同型）。
    def test_state_is_bound_to_the_issuing_account
      state = @service.send(:create_state)

      assert_raises(Ginseng::AuthError, '別アカウントで通ってしまう') do
        service_for(ACCOUNT_ID + 1).send(:verify_state!, state)
      end
    end

    # ⚠ アカウントを持たない呼び出しでは発行しない（縛れないものを配らない）。
    def test_state_is_not_issued_without_an_account
      assert_raises(Ginseng::AuthError) {service_for(nil).send(:create_state)}
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

    def service_for(account_id)
      service = SpotifyUserService.allocate
      service.define_singleton_method(:account_id) {account_id}
      return service
    end

    # 設定（`client_id` / accounts の URL）に依存する部分だけ差し替える。
    # ⚠ 見たいのは **`state` が載ること**なので、それ以外は最小限で足りる。
    def stubbed_service
      service = service_for(ACCOUNT_ID)
      service.define_singleton_method(:accounts_service) do
        double = Object.new
        double.define_singleton_method(:create_uri) do |path|
          Ginseng::URI.parse("https://accounts.example#{path}")
        end
        double
      end
      service.define_singleton_method(:redirect_uri) {'http://127.0.0.1:8888/spotify/callback'}
      service.define_singleton_method(:scopes) {['user-read-currently-playing']}
      service.singleton_class.define_method(:client_id) {'test-client'}
      return service
    end

    def state_of(uri)
      return Ginseng::URI.parse(uri.to_s).query_values['state']
    end
  end
end
