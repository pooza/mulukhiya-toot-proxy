require 'rack/test'

module Mulukhiya
  # OAuth の state を、発行したブラウザに縛る (#4726)。
  #
  # 🔴 `/mulukhiya/app/:page` は認証なしで state を発行する。state が有効かどうかだけを見ると、
  # 攻撃者が自分のアカウントで認可した `code` と state を載せた callback の URL を被害者に
  # 踏ませて、被害者の Web UI に攻撃者のトークンを入れられる（ログイン CSRF）。
  class OAuthBrowserBindingTest < TestCase
    include Rack::Test::Methods

    class ServiceDouble
      include SNSMethods
      include SNSServiceMethods

      attr_reader :exchanged

      def controller_class = MastodonController

      def oauth_token_request(code, code_verifier:, redirect_uri:, type: :default)
        @exchanged = {code:, code_verifier:, redirect_uri:}
        return :token
      end

      def oauth_callback_uri = 'https://example.com/mulukhiya/oauth/callback'
    end

    class NonceProbeController < UIController
      set :raise_errors, false
      set :show_exceptions, false

      get '/nonce' do
        @renderer = default_renderer_class.new
        @renderer.message = {nonce: oauth_browser_nonce}
        return @renderer.to_s
      end
    end

    def app = NonceProbeController

    def disable?
      OAuthHelper.storage.get('1')
      return super
    rescue
      return true
    end

    def setup
      @service = ServiceDouble.new
    end

    def test_same_browser_is_accepted
      state = issue('nonce-of-the-victim-browser-000000000000')

      assert_equal(:token, @service.auth_with_pkce('code', state, browser: 'nonce-of-the-victim-browser-000000000000'))
      assert_equal('code', @service.exchanged[:code])
    end

    # 🔴 本体。攻撃者が自分のブラウザで発行させた state は、被害者のブラウザでは通らない。
    def test_other_browser_is_rejected
      state = issue('nonce-of-the-attacker-browser-00000000000')

      assert_raise(Ginseng::AuthError) do
        @service.auth_with_pkce('code', state, browser: 'nonce-of-the-victim-browser-000000000000')
      end
      assert_nil(@service.exchanged, 'トークン交換まで進んでいる')
    end

    def test_missing_cookie_is_rejected
      state = issue('nonce-of-the-attacker-browser-00000000000')

      assert_raise(Ginseng::AuthError) {@service.auth_with_pkce('code', state, browser: nil)}
      assert_nil(@service.exchanged)
    end

    # ⚠ 目印なしで発行された state は通さない（「目印が無ければ素通り」にしない）。
    def test_state_without_browser_is_rejected
      state = OAuthHelper.create_oauth_state(sns_type: 'mastodon')[:state]

      assert_raise(Ginseng::AuthError) {@service.auth_with_pkce('code', state, browser: nil)}
      assert_raise(Ginseng::AuthError) do
        @service.auth_with_pkce('code', issue(nil), browser: 'nonce-of-the-victim-browser-000000000000')
      end
      assert_nil(@service.exchanged)
    end

    # ⚠ 突き合わせに失敗した state も消費されている（同じ state を別の Cookie で撃ち直せない）。
    def test_rejected_state_is_consumed
      state = issue('nonce-of-the-attacker-browser-00000000000')
      assert_raise(Ginseng::AuthError) {@service.auth_with_pkce('code', state, browser: 'x')}

      assert_raise(Ginseng::AuthError) do
        @service.auth_with_pkce('code', state, browser: 'nonce-of-the-attacker-browser-00000000000')
      end
    end

    # ⚠ Redis に置くのはダイジェスト（値そのものを置かない）。
    def test_storage_keeps_digest_only
      state = issue('nonce-of-the-victim-browser-000000000000')
      stored = OAuthHelper.storage.get(state)

      assert_equal(Digest::SHA256.hexdigest('nonce-of-the-victim-browser-000000000000'), stored[:browser])
    ensure
      OAuthHelper.consume_oauth_state(state)
    end

    def test_cookie_is_issued_with_safe_attributes
      get('/nonce', {}, {'HTTP_HOST' => 'localhost', 'HTTPS' => 'on'})
      cookie = last_response.headers['set-cookie'].to_s

      assert_match(/\Amulukhiya_oauth_browser=[\w-]{32,}/, cookie)
      assert_match(/httponly/i, cookie)
      assert_match(/samesite=lax/i, cookie)
      assert_match(/secure/i, cookie)
      assert_match(%r{path=/mulukhiya}i, cookie)
    end

    def test_existing_cookie_is_reused
      nonce = 'a' * 43
      get('/nonce', {}, {'HTTP_HOST' => 'localhost', 'HTTP_COOKIE' => "mulukhiya_oauth_browser=#{nonce}"})

      assert_equal(nonce, JSON.parse(last_response.body)['nonce'])
    end

    # ⚠ 形の合わない値は目印にしない（作り直す）。
    def test_malformed_cookie_is_replaced
      get('/nonce', {}, {'HTTP_HOST' => 'localhost', 'HTTP_COOKIE' => 'mulukhiya_oauth_browser=short'})

      assert_not_equal('short', JSON.parse(last_response.body)['nonce'])
    end

    # 🔴 壊れた UTF-8 の Cookie でも 500 にしない（5.40.0 のリリース前レビュー）。
    def test_invalid_utf8_cookie_is_replaced
      cookie = "mulukhiya_oauth_browser=%E3%81#{'a' * 40}"
      get('/nonce', {}, {'HTTP_HOST' => 'localhost', 'HTTP_COOKIE' => cookie})

      assert_equal(200, last_response.status)
      assert_match(/\A[\w-]{32,128}\z/, JSON.parse(last_response.body)['nonce'])
    end

    private

    def issue(browser)
      digest = OAuthHelper.browser_digest(browser)
      return OAuthHelper.create_oauth_state(sns_type: 'mastodon', browser: digest)[:state]
    end
  end
end
