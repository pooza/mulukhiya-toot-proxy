module Mulukhiya
  class MisskeyController < Controller
    before do
      if params[:token].present? && home?
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif params[:i]
        @sns.token = params[:i]
      else
        @sns.token = nil
      end
    end

    post '/api/notes/create' do
      Handler.dispatch(:pre_toot, params, {reporter: @reporter, sns: @sns}) unless renote?
      params.delete(status_field) if params[status_field].empty?
      @reporter.response = @sns.note(params)
      notify(@reporter.response.parsed_response) if response_error?
      Handler.dispatch(:post_toot, params, {reporter: @reporter, sns: @sns}) unless renote?
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Handler.dispatch(:pre_upload, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        filename: params[:file][:filename],
      })
      notify(@reporter.response.parsed_response) if response_error?
      Handler.dispatch(:post_upload, params, {reporter: @reporter, sns: @sns})
      @renderer.message = JSON.parse(@reporter.response.body)
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      notify(@renderer.message)
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      @reporter.response = @sns.fav(params[:noteId])
      Handler.dispatch(:post_bookmark, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response || {}
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    get '/mulukhiya/auth' do
      @renderer = SlimRenderer.new
      errors = MisskeyAuthContract.new.exec(params)
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

    def renote?
      return params[:renoteId].present?
    end

    def self.name
      return 'Misskey'
    end

    def self.webhook?
      return true
    end

    def self.tag_feed?
      return TagContainer.default_tags.present?
    end

    def self.clipping?
      return true
    end

    def self.announcement?
      return true
    end

    def self.parser_class
      return "Mulukhiya::#{parser_name.camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{dbms_name.camelize}".constantize
    end

    def self.postgres?
      return dbms_name == 'postgres'
    end

    def self.mongo?
      return dbms_name == 'mongo'
    end

    def self.dbms_name
      return config['/misskey/dbms']
    end

    def self.parser_name
      return config['/misskey/parser']
    end

    def self.status_field
      return config['/misskey/status/field']
    end

    def self.status_key
      return config['/misskey/status/key']
    end

    def self.attachment_key
      return config['/misskey/attachment/key']
    end

    def self.poll_options_field
      return config['/misskey/poll/options/field']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return config['/misskey/status/label']
    end

    def self.events
      return config['/misskey/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Misskey::AccessToken.order(Sequel.desc(:createdAt)).all do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
