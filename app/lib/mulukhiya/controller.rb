require 'omniauth'
require 'omniauth-twitter'

module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    set :root, Environment.dir
    enable :sessions, :method_override

    use OmniAuth::Builder do
      provider :twitter, TwitterService.consumer_key, TwitterService.consumer_secret
    end

    before do
      @sns = Environment.sns_class.new
      @reporter = Reporter.new
    end

    get '/mulukhiya' do
      @renderer = SlimRenderer.new
      @renderer.template = 'home'
      return @renderer.to_s
    end

    get '/mulukhiya/feed/tag/:tag' do
      if Environment.controller_class.tag_feed?
        @renderer = TagAtomFeedRenderer.new
        @renderer.tag = params[:tag]
        @renderer.status = 404 unless @renderer.exist?
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/feed/media' do
      if Environment.controller_class.media_catalog?
        @renderer = MediaAtomFeedRenderer.new

      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/about' do
      @renderer.message = {package: @config.raw.dig('application', 'package')}
      return @renderer.to_s
    end

    get '/mulukhiya/config' do
      if @sns.account
        @renderer.message = user_config_info
      else
        @renderer.message = {error: 'Invalid token'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/mulukhiya/config' do
      Handler.create('user_config_command').handle_toot(params, {sns: @sns})
      @renderer.message = user_config_info
      return @renderer.to_s
    rescue Ginseng::AuthError, Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      @renderer.status = e.status
      return @renderer.to_s
    end

    get '/mulukhiya/programs' do
      path = File.join(Environment.dir, 'tmp/cache/programs.json')
      if File.readable?(path)
        @renderer.message = JSON.parse(File.read(path))
      else
        @renderer.message = []
      end
      return @renderer.to_s
    end

    get '/mulukhiya/health' do
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/mulukhiya/app/:page' do
      @renderer = SlimRenderer.new
      @renderer.template = params[:page]
      @renderer[:oauth_url] = @sns.oauth_uri
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    get '/mulukhiya/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    post '/mulukhiya/annict/auth' do
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif @sns.account
        r = AnnictService.new.auth(params['code'])
        if r.code == 200
          @sns.account.config.update(annict: {token: r['access_token']})
          @sns.account.annict.updated_at = Time.now
          @renderer.message = user_config_info
        else
          @renderer.message = r.parsed_response
        end
        @renderer.status = r.code
      else
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    get '/auth/twitter/callback' do
      errors = TwitterAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif @sns.account
        @sns.account.config.update(twitter: request.env['omniauth.auth'][:credentials])
        @renderer = SlimRenderer.new
        @renderer.template = 'config'
      else
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer = default_renderer_class.new
      @renderer.status = e.status
      @renderer.message = e.to_h
      @renderer.message.delete(:backtrace)
      @renderer.message[:error] = e.message
      Slack.broadcast(e)
      @logger.error(e)
      return @renderer.to_s
    end

    def self.config
      return Config.instance
    end

    def self.webhook_entries
      return nil
    end

    private

    def response_error?
      return 400 <= @reporter.response&.code
    end

    def home?
      return true if request.path.start_with?('/mulukhiya')
      return true if request.path.start_with?('/auth')
      return false
    end

    def user_config_info
      return {
        account: @sns.account.to_h,
        config: @sns.account.config.to_h,
        filters: @sns.filters&.parsed_response,
        token: @sns.access_token.to_h,
        visibility_names: Environment.parser_class.visibility_names,
      }
    end

    def notify(message)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(@sns.account, message)
    end

    def status_field
      return Environment.controller_class.status_field
    end
  end
end
