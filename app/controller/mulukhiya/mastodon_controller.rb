module Mulukhiya
  class MastodonController < Controller
    before do
      @mastodon = MastodonService.new
      if params[:token].present?
        @mastodon.token = Crypt.new.decrypt(params[:token])
      elsif @headers['Authorization']
        @mastodon.token = @headers['Authorization'].split(/\s+/).last
      end
      @results.account = @mastodon.account
    end

    post '/api/v1/statuses' do
      tags = TootParser.new(params[:status]).tags
      Handler.exec_all(:pre_toot, params, {results: @results, sns: @mastodon})
      @results.response = @mastodon.toot(params)
      notify(@mastodon.account, @results.response.parsed_response) if response_error?
      Handler.exec_all(:post_toot, params, {results: @results, sns: @mastodon})
      @renderer.message = @results.response.parsed_response
      @renderer.message['tags']&.keep_if {|v| tags.member?(v['name'])}
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      notify(@mastodon.account, @renderer.message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/v1/media' do
      Handler.exec_all(:pre_upload, params, {results: @results, sns: @mastodon})
      @results.response = @mastodon.upload(params[:file][:tempfile].path, {response: :raw})
      Handler.exec_all(:post_upload, params, {results: @results, sns: @mastodon})
      @renderer.message = JSON.parse(@results.response.body)
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = JSON.parse(e.response.body)
      notify(@mastodon.account, @renderer.message)
      @renderer.status = e.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/favourite' do
      @results.response = @mastodon.fav(params[:id])
      Handler.exec_all(:post_fav, params, {results: @results, sns: @mastodon})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      @results.response = @mastodon.boost(params[:id])
      Handler.exec_all(:post_boost, params, {results: @results, sns: @mastodon})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/bookmark' do
      @results.response = @mastodon.bookmark(params[:id])
      Handler.exec_all(:post_bookmark, params, {results: @results, sns: @mastodon})
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    get '/api/v2/search' do
      params[:limit] = @config['/mastodon/search/limit']
      @results.response = @mastodon.search(params[:q], params)
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

    get '/mulukhiya/config' do
      if @mastodon.account
        @renderer.message = UserConfigStorage.new.get(@mastodon.account.id)
      else
        @renderer.message = {error: 'bad token'}
        @renderer.status = 400
      end
      return @renderer.to_s
    end

    get '/mulukhiya/app/auth' do
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_auth'
      @renderer[:oauth_url] = @mastodon.oauth_uri
      return @renderer.to_s
    end

    post '/mulukhiya/app/auth' do
      @renderer = HTMLRenderer.new
      errors = AppAuthContract.new.call(params).errors.to_h
      if errors.present?
        @renderer.template = 'app_auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @mastodon.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'app_auth_result'
        r = @mastodon.auth(params[:code])
        @mastodon.token = r.parsed_response['access_token']
        @mastodon.account.webhook_token = @mastodon.token if @mastodon.token
        @renderer[:hook_url] = @mastodon.account.webhook&.uri
        @renderer[:status] = r.code
        @renderer[:result] = r.parsed_response
        @renderer.status = r.code
      end
      return @renderer.to_s
    end

    get '/mulukhiya/app/config' do
      @renderer = HTMLRenderer.new
      @renderer.template = 'app_config'
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
