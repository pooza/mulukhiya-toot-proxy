module Mulukhiya
  class MisskeyController < Controller
    before do
      @sns = Environment.sns_class.new
      if params[:token].present? && request.path.start_with?('/mulukhiya')
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif params[:i]
        @sns.token = params[:i]
      end
      @results.account = @sns.account
    end

    post '/api/notes/create' do
      Handler.exec_all(:pre_toot, params, {results: @results, sns: @sns}) unless renote?
      @results.response = @sns.note(params)
      notify(@results.response.parsed_response) if response_error?
      Handler.exec_all(:post_toot, params, {results: @results, sns: @sns}) unless renote?
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      notify(@renderer.message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Handler.exec_all(:pre_upload, params, {results: @results, sns: @sns})
      @results.response = @sns.upload(params[:file][:tempfile].path)
      notify(@results.response.parsed_response) if response_error?
      Handler.exec_all(:post_upload, params, {results: @results, sns: @sns})
      @renderer.message = JSON.parse(@results.response.body)
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      notify(@renderer.message)
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      @results.response = @sns.fav(params[:noteId])
      Handler.exec_all(:post_bookmark, params, {results: @results, sns: @sns})
      @renderer.message = @results.response.parsed_response || {}
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    get '/mulukhiya/auth' do
      @renderer = SlimRenderer.new
      errors = MisskeyAuthContract.new.call(params).errors.to_h
      if errors.present?
        @renderer.template = 'auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'auth_result'
        r = @sns.auth(params[:token])
        if r.code == 200
          @sns.token = @sns.create_access_token(r.parsed_response['accessToken'])
          @sns.account.config.webhook_token = @sns.token
          @renderer[:hook_url] = @sns.account.webhook&.uri
        end
        @renderer[:status] = r.code
        @renderer[:result] = {access_token: @sns.token}
        @renderer.status = r.code
      end
      return @renderer.to_s
    end

    get '/mulukhiya/note/:note' do
      note = Environment.status_class[params[:note]]
      if note.nil? || !note.visible?
        @renderer.status = 404
      else
        @renderer.message = note.to_h
        @renderer.message[:account] = Environment.account_class[note.userId].to_h
      end
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present?
    end

    def self.name
      return 'Misskey'
    end

    def self.webhook?
      return true
    end

    def self.announcement?
      return true
    end

    def self.status_field
      return Config.instance['/misskey/status/field']
    end

    def self.status_key
      return Config.instance['/misskey/status/key']
    end

    def self.attachment_key
      return Config.instance['/misskey/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/misskey/status/visibility_names/#{name}"]
    end

    def self.events
      return Config.instance['/misskey/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      config = Config.instance
      Misskey::AccessToken.all do |token|
        values = {
          digest: Webhook.create_digest(config['/misskey/url'], token.values[:hash]),
          token: token.values[:hash],
          account: token.account,
        }
        yield values
      end
    end
  end
end
