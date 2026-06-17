module Mulukhiya
  class SpotifyUserServiceTest < TestCase
    def setup
      config['/service/spotify/client/id'] = 'test_client_id'
      config['/service/spotify/client/secret'] = 'test_client_secret'
      config['/service/spotify/oauth/user_oauth_enabled'] = true
      # repeat の内部リトライ (config['/http/retry/limit']) が WebMock の逐次レスポンスを
      # 食ってしまい 401→refresh の検証が非決定になるため、テストでは無効化する。
      config['/http/retry/limit'] = 1
    end

    def test_config_true_when_enabled
      assert_predicate(SpotifyUserService, :config?)
    end

    def test_config_false_when_user_oauth_disabled
      config['/service/spotify/oauth/user_oauth_enabled'] = false

      assert_false(SpotifyUserService.config?)
    end

    def test_config_false_without_client_id
      config['/service/spotify/client/id'] = nil

      assert_false(SpotifyUserService.config?)
    end

    def test_oauth_uri
      uri = SpotifyUserService.new.oauth_uri

      assert_equal('accounts.spotify.com', uri.host)
      assert_equal('/authorize', uri.path)
      query = uri.query_values

      assert_equal('test_client_id', query['client_id'])
      assert_equal('code', query['response_type'])
      assert_equal('user-read-currently-playing', query['scope'])
      assert_equal(config['/service/spotify/oauth/redirect_uri'], query['redirect_uri'])
    end

    def test_auth_exchanges_code_and_stores_tokens
      stub = stub_token_endpoint(
        access_token: 'access-1', refresh_token: 'refresh-1', expires_in: 3600,
      )
      account = account_double

      SpotifyUserService.new(account).auth('the-code')

      assert_requested(stub.with do |req|
        body = URI.decode_www_form(req.body).to_h
        body['grant_type'] == 'authorization_code' && body['code'] == 'the-code'
      end)
      assert_equal('access-1', account.user_config['/service/spotify/token'])
      assert_equal('refresh-1', account.user_config['/service/spotify/refresh_token'])
      assert_operator(account.user_config['/service/spotify/expires_at'], :>, Time.now.to_i)
    end

    def test_currently_playing_returns_track_url
      account = account_double(
        '/service/spotify/token' => 'access-1',
        '/service/spotify/refresh_token' => 'refresh-1',
        '/service/spotify/expires_at' => Time.now.to_i + 3600,
      )
      stub_currently_playing(status: 200, body: {
        is_playing: true,
        item: {external_urls: {spotify: 'https://open.spotify.com/track/abc123'}},
      })

      assert_equal(
        'https://open.spotify.com/track/abc123',
        SpotifyUserService.new(account).currently_playing,
      )
    end

    def test_currently_playing_returns_nil_when_nothing_playing
      account = account_double(
        '/service/spotify/token' => 'access-1',
        '/service/spotify/refresh_token' => 'refresh-1',
        '/service/spotify/expires_at' => Time.now.to_i + 3600,
      )
      stub_currently_playing(status: 204, body: '')

      assert_nil(SpotifyUserService.new(account).currently_playing)
    end

    def test_currently_playing_refreshes_when_token_expired
      account = account_double(
        '/service/spotify/token' => 'stale',
        '/service/spotify/refresh_token' => 'refresh-1',
        '/service/spotify/expires_at' => Time.now.to_i - 1,
      )
      token_stub = stub_token_endpoint(access_token: 'access-2', expires_in: 3600)
      stub_currently_playing(status: 200, body: {
        item: {external_urls: {spotify: 'https://open.spotify.com/track/xyz'}},
      })

      url = SpotifyUserService.new(account).currently_playing

      assert_equal('https://open.spotify.com/track/xyz', url)
      assert_requested(token_stub)
      assert_equal('access-2', account.user_config['/service/spotify/token'])
      # Spotify が refresh_token を返さなかった場合は既存値を保持する。
      assert_equal('refresh-1', account.user_config['/service/spotify/refresh_token'])
    end

    def test_currently_playing_refreshes_on_401_then_retries
      account = account_double(
        '/service/spotify/token' => 'access-1',
        '/service/spotify/refresh_token' => 'refresh-1',
        '/service/spotify/expires_at' => Time.now.to_i + 3600,
      )
      stub_token_endpoint(access_token: 'access-2', expires_in: 3600)
      stub_request(:get, currently_playing_url).to_return(
        {status: 401, body: '{}', headers: {'Content-Type' => 'application/json'}},
        {status: 200, body: {item: {external_urls: {spotify: 'https://open.spotify.com/track/r'}}}.to_json,
         headers: {'Content-Type' => 'application/json'}},
      )

      assert_equal(
        'https://open.spotify.com/track/r',
        SpotifyUserService.new(account).currently_playing,
      )
      assert_equal('access-2', account.user_config['/service/spotify/token'])
    end

    def test_currently_playing_raises_auth_error_when_refresh_token_revoked
      account = account_double(
        '/service/spotify/token' => 'access-1',
        '/service/spotify/refresh_token' => 'revoked',
        '/service/spotify/expires_at' => Time.now.to_i - 1,
      )
      stub_request(:post, token_url).to_return(
        status: 400, body: {error: 'invalid_grant'}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      assert_raises(Ginseng::AuthError) do
        SpotifyUserService.new(account).currently_playing
      end
    end

    def test_unlink_clears_tokens
      account = account_double(
        '/service/spotify/token' => 'access-1',
        '/service/spotify/refresh_token' => 'refresh-1',
        '/service/spotify/expires_at' => Time.now.to_i + 3600,
      )

      SpotifyUserService.new(account).unlink

      assert_nil(account.user_config['/service/spotify/token'])
      assert_nil(account.user_config['/service/spotify/refresh_token'])
      assert_nil(account.user_config['/service/spotify/expires_at'])
    end

    private

    def token_url
      return "#{config['/service/spotify/urls/accounts']}/api/token"
    end

    def currently_playing_url
      return "#{config['/service/spotify/urls/api']}/v1/me/player/currently-playing"
    end

    def stub_token_endpoint(access_token:, expires_in:, refresh_token: nil)
      body = {access_token:, token_type: 'Bearer', expires_in:}
      body[:refresh_token] = refresh_token if refresh_token
      return stub_request(:post, token_url).to_return(
        status: 200, body: body.to_json, headers: {'Content-Type' => 'application/json'},
      )
    end

    def stub_currently_playing(status:, body:)
      payload = body.is_a?(String) ? body : body.to_json
      return stub_request(:get, currently_playing_url).to_return(
        status:, body: payload, headers: {'Content-Type' => 'application/json'},
      )
    end

    # 実 Account/UserConfig (DB・Redis 依存) を避けるための最小ダブル。
    # UserConfig は暗号化値をそのまま保持し read 時に復号しない仕様だが、本ダブルは
    # 平文を保持する (service 側 decrypt は復号失敗時に値をそのまま返すため整合する)。
    def account_double(store = {})
      user_config = FakeUserConfig.new(store)
      return Struct.new(:user_config).new(user_config)
    end

    class FakeUserConfig
      def initialize(store = {})
        @store = store.dup
      end

      def [](key)
        return @store[key]
      end

      def update(values)
        flatten(values.deep_stringify_keys).each do |key, value|
          if value.nil?
            @store.delete(key)
          else
            @store[key] = value
          end
        end
      end

      def to_h
        return @store.dup
      end

      private

      def flatten(hash, prefix = '')
        result = {}
        hash.each do |key, value|
          path = "#{prefix}/#{key}"
          if value.is_a?(Hash)
            result.merge!(flatten(value, path))
          else
            result[path] = value
          end
        end
        return result
      end
    end
  end
end
