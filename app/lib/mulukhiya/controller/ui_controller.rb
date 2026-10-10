module Mulukhiya
  class UIController < Controller
    # OAuth の state を、発行したブラウザに縛るための目印を置く Cookie (#4726)。
    OAUTH_BROWSER_COOKIE = 'mulukhiya_oauth_browser'.freeze
    OAUTH_BROWSER_COOKIE_MAX_AGE = 30 * 24 * 60 * 60

    get '/' do
      @renderer = SlimRenderer.new
      @renderer.template = 'home'
      return @renderer.to_s
    end

    get '/app/:page' do
      if params[:page] == 'test' && !config['/diag/enable']
        raise Ginseng::NotFoundError, 'Not Found'
      end
      @renderer = SlimRenderer.new
      @renderer.template = params[:page]
      @renderer[:oauth_url] = sns.oauth_uri(browser: oauth_browser_nonce)
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/oauth/callback' do
      unless params[:state] && params[:code]
        @renderer = SlimRenderer.new
        @renderer.template = 'token_error'
        @renderer[:error] = 'Missing required OAuth parameters'
        @renderer.status = 400
        return @renderer.to_s
      end
      result = sns.auth_with_pkce(
        params[:code],
        params[:state],
        browser: request.cookies[OAUTH_BROWSER_COOKIE],
      )
      raise Ginseng::AuthError, 'Token exchange failed' unless result
      parsed = result.parsed_response
      access_token = parsed['access_token'] || parsed['accessToken']
      raise Ginseng::AuthError, 'No access token in response' unless access_token
      if info_bot_token?(access_token)
        config.update_file(agent: {info: {token: encrypt_token!(access_token)}})
        config.reload
      end
      token_crypt = encrypt_token!(access_token)
      @renderer.status = 302
      redirect_url = "/mulukhiya/app/token_complete?token=#{Rack::Utils.escape(token_crypt)}"
      response['Location'] = redirect_url
      return ''
    rescue => e
      report_error(e)
      @renderer = SlimRenderer.new
      @renderer.template = 'token_error'
      @renderer[:error] = public_error_message(e)
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      return @renderer.to_s
    end

    get '/app/status/:id' do
      raise Ginseng::NotFoundError, 'Not Found' unless controller_class.repost?
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail'
      @renderer[:id] = params[:id]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    rescue Ginseng::AuthError
      @renderer.status = 403
    end

    get '/app/status/:id/nowplaying' do
      @renderer = SlimRenderer.new
      @renderer.template = 'status_detail_nowplaying'
      @renderer[:id] = params[:id]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    rescue Ginseng::AuthError
      @renderer.status = 403
    end

    get '/media/:name' do
      @renderer = StaticMediaRenderer.new
      @renderer.name = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/style/:name' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/script/test/:name' do
      raise Ginseng::NotFoundError, 'Not Found' unless config['/diag/enable']
      @renderer = ScriptRenderer.new
      @renderer.name = "test/#{params[:name]}"
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    get '/script/:name' do
      @renderer = ScriptRenderer.new
      @renderer.name = params[:name]
      return @renderer.to_s
    rescue Ginseng::RenderError, Ginseng::NotFoundError
      @renderer.status = 404
    end

    # state を発行したブラウザの目印。無ければ作って Cookie に置く (#4726)。
    #
    # ⚠ **HttpOnly・SameSite=Lax。**callback は SNS からのトップレベルの GET で戻ってくるので、
    # Lax なら届く（Strict だと届かずログインできなくなる）。
    # ⚠ 形の合わない値は捨てて作り直す（他所が置いた値をそのまま目印にしない）。
    # 🔴 **壊れた UTF-8 も「形の合わない値」**（5.40.0 のリリース前レビュー）。Rack は Cookie の値を
    # percent-decode するので、`%E3%81` のような値は不正なバイト列になり、正規表現に掛けると
    # `ArgumentError` で 500 ＋アラートになる。入口の検査 (#4600) は Cookie を見ない。
    def oauth_browser_nonce
      nonce = request.cookies[OAUTH_BROWSER_COOKIE].to_s
      valid = nonce.valid_encoding? && nonce.match?(/\A[\w-]{32,128}\z/)
      nonce = SecureRandom.urlsafe_base64(32) unless valid
      response.set_cookie(OAUTH_BROWSER_COOKIE, {
        value: nonce,
        path: '/mulukhiya',
        httponly: true,
        same_site: :lax,
        secure: request.ssl?,
        max_age: OAUTH_BROWSER_COOKIE_MAX_AGE,
      })
      return nonce
    end

    def token
      return params[:token].decrypt
    rescue
      return params[:token]
    end

    def info_bot_token?(access_token)
      info_username = config['/agent/info/username']
      return false unless info_username
      account = Environment.account_class.get(token: access_token)
      return account&.username == info_username
    rescue
      return false
    end

    def self.media_copyright
      return {
        message: config['/webui/media/copyright/message'],
        url: config['/webui/media/copyright/url'],
      }
    rescue Ginseng::ConfigError
      return nil
    end
  end
end
