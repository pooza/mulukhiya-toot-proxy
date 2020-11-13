module Mulukhiya
  class APIController < Controller
    get '/about' do
      @sns.token ||= @sns.default_token
      @renderer.message = {package: @config.raw.dig('application', 'package')}
      return @renderer.to_s
    end

    get '/config' do
      if @sns.account
        @renderer.message = user_config_info
      else
        @renderer.message = {error: 'Invalid token'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/config' do
      Handler.create('user_config_command').handle_toot(params, {sns: @sns})
      @renderer.message = user_config_info
      return @renderer.to_s
    rescue Ginseng::AuthError, Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/filter' do
      Handler.create('filter_command').handle_toot(params, {sns: @sns})
      @renderer.message = {filters: @sns.filters}
      return @renderer.to_s
    end

    get '/programs' do
      @sns.token ||= @sns.default_token
      path = File.join(Environment.dir, 'tmp/cache/programs.json')
      if File.readable?(path)
        @renderer.message = JSON.parse(File.read(path))
      else
        @renderer.message = []
      end
      return @renderer.to_s
    end

    get '/medias' do
      @sns.token ||= @sns.default_token
      if Environment.controller_class.media_catalog?
        @renderer.message = Environment.attachment_class.catalog
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/health' do
      @sns.token ||= @sns.default_token
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    post '/annict/auth' do
      errors = AnnictAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif @sns.account
        response = AnnictService.new.auth(params['code'])
        @sns.account.config.update(annict: {token: response['access_token']})
        @sns.account.annict.updated_at = Time.now
        @renderer.message = user_config_info
        @renderer.status = response.code
      else
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    def token
      return Crypt.new.decrypt(params[:token]) if params[:token]
      return nil
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
  end
end
