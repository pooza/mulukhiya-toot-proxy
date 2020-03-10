module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    set :root, Environment.dir

    before do
      @results = ResultContainer.new
    end

    get '/mulukhiya' do
      @renderer = SlimRenderer.new
      @renderer.template = 'home'
      return @renderer.to_s
    end

    get '/mulukhiya/about' do
      path = File.join(Environment.dir, 'config/application.yaml')
      @renderer.message = {package: YAML.load_file(path)['package']}
      return @renderer.to_s
    end

    get '/mulukhiya/config' do
      if @sns.account
        @renderer.message = {
          account: @sns.account.to_h,
          config: @sns.account.config.to_h,
        }
      else
        @renderer.message = {error: 'Invalid access token'}
        @renderer.status = 400
      end
      return @renderer.to_s
    end

    post '/mulukhiya/config' do
      Handler.create('user_config_command').handle_toot(params, {sns: @sns})
      @renderer.message = {
        account: @sns.account.to_h,
        config: @sns.account.config.to_h,
      }
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      @renderer.status = e.status
      return @renderer.to_s
    end

    get '/mulukhiya/health' do
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/mulukhiya/app/health' do
      @renderer = SlimRenderer.new
      @renderer.template = 'health'
      return @renderer.to_s
    end

    get '/mulukhiya/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    def response_error?
      return 400 <= @results.response&.code
    end

    def notify(message)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(@sns.account, message)
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
  end
end
