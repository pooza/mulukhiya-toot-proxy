module Mulukhiya
  class MastodonController < Controller
    before do
      @sns = MastodonService.new
      if params[:token].present? && request.path.start_with?('/mulukhiya')
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif @headers['Authorization']
        @sns.token = @headers['Authorization'].split(/\s+/).last
      end
      @results.account = @sns.account
    end

    post '/api/v1/statuses' do
      tags = TootParser.new(params[:status]).tags
      Handler.exec_all(:pre_toot, params, {results: @results, sns: @sns})
      @results.response = @sns.toot(params)
      notify(@results.response.parsed_response) if response_error?
      Handler.exec_all(:post_toot, params, {results: @results, sns: @sns})
      @renderer.message = @results.response.parsed_response
      @renderer.message['tags']&.keep_if {|v| tags.member?(v['name'])}
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      notify(@renderer.message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/v1/media' do
      Handler.exec_all(:pre_upload, params, {results: @results, sns: @sns})
      @results.response = @sns.upload(params[:file][:tempfile].path, {response: :raw})
      Handler.exec_all(:post_upload, params, {results: @results, sns: @sns})
      @renderer.message = JSON.parse(@results.response.body)
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = JSON.parse(e.response.body)
      notify(@renderer.message)
      @renderer.status = e.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/favourite' do
      @results.response = @sns.fav(params[:id])
      Handler.exec_all(:post_fav, params, {results: @results, sns: @sns})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      @results.response = @sns.boost(params[:id])
      Handler.exec_all(:post_boost, params, {results: @results, sns: @sns})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/bookmark' do
      @results.response = @sns.bookmark(params[:id])
      Handler.exec_all(:post_bookmark, params, {results: @results, sns: @sns})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    get '/api/v2/search' do
      params[:limit] = @config['/mastodon/search/limit']
      @results.response = @sns.search(params[:q], params)
      @message = @results.response.parsed_response.with_indifferent_access
      Handler.exec_all(:post_search, params, {results: @results, message: @message})
      @renderer.message = @message
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/mulukhiya/webhook/:digest' do
      errors = WebhookContract.new.call(params).errors.to_h
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif webhook = Webhook.create(params[:digest])
        results = webhook.toot(params)
        @renderer.message = results.response.parsed_response
        @renderer.status = results.response.code
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      if Webhook.create(params[:digest])
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/app/auth' do
      @renderer = SlimRenderer.new
      @renderer.template = 'app_auth'
      @renderer[:oauth_url] = @sns.oauth_uri
      return @renderer.to_s
    end

    post '/mulukhiya/app/auth' do
      @renderer = SlimRenderer.new
      errors = AppAuthContract.new.call(params).errors.to_h
      if errors.present?
        @renderer.template = 'app_auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'app_auth_result'
        r = @sns.auth(params[:code])
        @sns.token = r.parsed_response['access_token']
        @sns.account.config.webhook_token = @sns.token if @sns.token
        @renderer[:hook_url] = @sns.account.webhook&.uri
        @renderer[:status] = r.code
        @renderer[:result] = r.parsed_response
        @renderer.status = r.code
      end
      return @renderer.to_s
    end

    get '/mulukhiya/app/config' do
      @renderer = SlimRenderer.new
      @renderer.template = 'app_config'
      return @renderer.to_s
    end

    post '/mulukhiya/config' do
      Handler.create('user_config_command').handle_toot(params)
      @renderer.message = {config: @sns.account.config.to_h}
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      @renderer.status = e.status
      return @renderer.to_s
    end

    get '/mulukhiya/programs' do
      path = File.join(Environment.dir, 'tmp/cache/programs.json')
      if File.readable?(path)
        @renderer.message = JSON.parse(File.read(path))
        return @renderer.to_s
      else
        @renderer.status = 404
      end
    end

    def self.name
      return 'Mastodon'
    end

    def self.webhook?
      return true
    end

    def self.announcement?
      return true
    end

    def self.status_field
      return Config.instance['/mastodon/status/field']
    end

    def self.status_key
      return Config.instance['/mastodon/status/key']
    end

    def self.attachment_key
      return Config.instance['/mastodon/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/mastodon/status/visibility_names/#{name}"]
    end

    def self.events
      return Config.instance['/mastodon/events'].map(&:to_sym)
    end
  end
end
