module Mulukhiya
  # capsicum のナウプレ投稿 (capsicum #465) 向けの user-level OAuth サービス (#4337)。
  #
  # 既存の SpotifyService (Client Credentials Flow / app-level、track 検索・lookup 用)
  # とは別系統で、Authorization Code Flow により当該ユーザーの
  # GET /v1/me/player/currently-playing を呼ぶ。capsicum に client_secret を置かず
  # サーバー (モロヘイヤ) がトークンを保管する点は Annict 連携 (#4338) と同方針。
  #
  # トークンは UserConfig (Redis、暗号化) に保管する。Spotify の access_token は
  # 3600s で失効するため refresh_token も保管し、失効時/401 時に自動更新する。
  # capsicum 側は code-post 方式で、ブラウザ認可後の code を POST /api/spotify/auth に
  # 渡すだけでよい (ユーザー特定は SNS トークンで行うため state は不要)。
  class SpotifyUserService
    include Package

    AUTHORIZE_PATH = '/authorize'.freeze
    TOKEN_PATH = '/api/token'.freeze
    CURRENTLY_PLAYING_PATH = '/v1/me/player/currently-playing'.freeze

    # account は currently_playing / auth / unlink で必要 (refresh したトークンを
    # UserConfig へ書き戻すため)。oauth_uri のみ account なしでも使える。
    def initialize(account = nil)
      @account = account
    end

    def oauth_uri
      uri = accounts_service.create_uri(AUTHORIZE_PATH)
      uri.query_values = {
        client_id: self.class.client_id,
        response_type: 'code',
        redirect_uri: redirect_uri,
        scope: scopes.join(' '),
      }
      return uri
    end

    # authorization code を access_token + refresh_token に交換し保管する。
    def auth(code)
      response = token_request(
        'grant_type' => 'authorization_code',
        'code' => code,
        'redirect_uri' => redirect_uri,
      )
      store_tokens(response.parsed_response)
      return response
    end

    # 現在再生中トラックの共有 URL を返す。無再生・広告・プライベートセッション
    # (204 / item なし) は nil。access_token 失効は事前 refresh で、保管値が古い等の
    # 401 は事後 refresh + 1 回リトライで吸収する。
    def currently_playing
      refresh! if expired?
      attempts = 0
      begin
        response = api_service.get(CURRENTLY_PLAYING_PATH, headers: bearer_headers)
        return nil if response.code == 204
        return extract_track_url(response.parsed_response)
      rescue Ginseng::GatewayError => e
        raise unless e.source_status == 401
        attempts += 1
        raise if attempts > 1
        refresh!
        retry
      end
    end

    # 連携解除。保管した access/refresh/expires_at を除去する (deep_compact で nil は
    # 削除されるため、これで未連携状態に戻る)。
    def unlink
      cleared = {token: nil, refresh_token: nil, expires_at: nil}
      return @account.user_config.update(service: {spotify: cleared})
    end

    def self.client_id
      return config['/service/spotify/client/id'] rescue nil
    end

    def self.client_secret
      return config['/service/spotify/client/secret'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/service/spotify/client/secret']
    end

    # user OAuth が利用可能か (features.spotify_enabled の正本)。Spotify Developer
    # Dashboard 側で Redirect URI / Scope 登録が済むまでは user_oauth_enabled を false に
    # しておき、capsicum に連携導線を出させない。
    def self.config?
      return false unless config['/service/spotify/oauth/user_oauth_enabled']
      return false unless client_id
      return false unless client_secret
      return true
    rescue => e
      e.log
      return false
    end

    private

    def redirect_uri
      return config['/service/spotify/oauth/redirect_uri']
    end

    def scopes
      return Array(config['/service/spotify/oauth/scopes'])
    end

    def access_token
      return decrypt(@account.user_config['/service/spotify/token'])
    end

    def refresh_token
      return decrypt(@account.user_config['/service/spotify/refresh_token'])
    end

    def expired?
      expires_at = @account.user_config['/service/spotify/expires_at']
      return true unless expires_at
      return Time.now.to_i >= expires_at.to_i
    end

    def refresh!
      raise Ginseng::AuthError, 'Spotify authentication required' unless refresh_token
      response = token_request(
        'grant_type' => 'refresh_token',
        'refresh_token' => refresh_token,
      )
      store_tokens(response.parsed_response)
      return response
    rescue Ginseng::GatewayError => e
      # refresh_token 失効/revoke (invalid_grant) は token endpoint が 4xx を返す。
      # これは再認証が必要なユーザー起因エラーなので AuthError (401) に倒し、
      # capsicum に再連携フローを誘導させる。5xx/timeout は Spotify 障害なので
      # GatewayError (502) のまま上げる。
      raise unless e.source_status&.between?(400, 499)
      raise Ginseng::AuthError, 'Spotify re-authentication required'
    end

    def token_request(params)
      return accounts_service.post(TOKEN_PATH, {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'client_id' => self.class.client_id,
          'client_secret' => self.class.client_secret,
        }.merge(params),
      })
    end

    def store_tokens(body)
      values = {
        token: body['access_token'],
        expires_at: Time.now.to_i + body['expires_in'].to_i,
      }
      # Spotify は refresh_token を毎回返すとは限らない。返らない場合は既存値を保持する
      # (上書きで消すと以降 refresh 不能になる)。
      values[:refresh_token] = body['refresh_token'] if body['refresh_token'].present?
      @account.user_config.update(service: {spotify: values})
    end

    def extract_track_url(body)
      return nil unless body.is_a?(Hash)
      item = body['item']
      return nil unless item.is_a?(Hash)
      return item.dig('external_urls', 'spotify').presence
    end

    def bearer_headers
      return {'Authorization' => "Bearer #{access_token}"}
    end

    # UserConfig は暗号化値をそのまま返す (read 時に復号しない) ため、利用側で復号する。
    def decrypt(value)
      return nil unless value
      return value.decrypt
    rescue
      return value
    end

    def accounts_service
      unless @accounts_service
        @accounts_service = HTTP.new
        @accounts_service.base_uri = config['/service/spotify/urls/accounts']
      end
      return @accounts_service
    end

    def api_service
      unless @api_service
        @api_service = HTTP.new
        @api_service.base_uri = config['/service/spotify/urls/api']
      end
      return @api_service
    end
  end
end
