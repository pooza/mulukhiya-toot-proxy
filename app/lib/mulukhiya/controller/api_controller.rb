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
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/config/update' do
      Handler.create('user_config_command').handle_toot(params, {sns: @sns})
      @renderer.message = user_config_info
      return @renderer.to_s
    rescue Ginseng::AuthError, Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/filter/add' do
      Handler.create('filter_command').handle_toot(params, {sns: @sns})
      @renderer.message = {filters: @sns.filters}
      return @renderer.to_s
    end

    get '/program' do
      @sns.token ||= @sns.default_token
      path = File.join(Environment.dir, 'tmp/cache/programs.json')
      if File.readable?(path)
        @renderer.message = JSON.parse(File.read(path))
      else
        @renderer.message = []
      end
      return @renderer.to_s
    end

    post '/program/update' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        ProgramUpdateWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    get '/media' do
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

    post '/announcement/update' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        AnnouncementWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/media/clear' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        MediaCleaningWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/oauth/client/clear' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        Environment.sns_class.new.clear_oauth_client
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/tagging/dic/update' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        TaggingDictionaryUpdateWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/tagging/usertag/clear' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        UserTagInitializeWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      end
      return @renderer.to_s
    end

    post '/feed/update' do
      if @sns.account.nil?
        @renderer.message = {error: 'Unauthorized'}
        @renderer.status = 403
      elsif @sns.account.admin? || @sns.account.moderator?
        TagFeedUpdateWorker.new.perform
      else
        @renderer.message = {error: 'Unauthorized'}
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
        token: @sns.access_token.to_h.reject {|k, v| k == :account},
        visibility_names: Environment.parser_class.visibility_names,
      }
    end
  end
end
