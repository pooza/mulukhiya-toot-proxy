module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    before do
      if params[:token].present? && home?
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif params[:i]
        @sns.token = params[:i]
      else
        @sns.token = nil
      end
    rescue => e
      @logger.error(controller: self.class.to_s, error: e.message)
      @renderer.status = 403
      @sns.token = nil
    end

    post '/api/notes/create' do
      Event.new(:pre_toot, {reporter: @reporter, sns: @sns}).dispatch(params) unless renote?
      params.delete(status_field) if params[status_field].empty?
      @reporter.response = @sns.note(params)
      notify(@reporter.response.parsed_response) if response_error?
      Event.new(:post_toot, {reporter: @reporter, sns: @sns}).dispatch(params) unless renote?
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.message.match(/ ([[:digit:]]{3})$/)[1]&.to_i || e.code
      return @renderer.to_s
    end

    post '/api/messaging/messages/create' do
      @reporter.tags.clear
      Event.new(:pre_chat, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.say(params)
      notify(@reporter.response.parsed_response) if response_error?
      Event.new(:post_chat, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.message.match(/ ([[:digit:]]{3})$/)[1]&.to_i || e.code
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Event.new(:pre_upload, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        filename: params[:file][:filename],
      })
      notify(@reporter.response.parsed_response) if response_error?
      Event.new(:post_upload, {reporter: @reporter, sns: @sns}).dispatch(params)
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
      Event.new(:pre_bookmark, {reporter: @reporter, sns: @sns}).dispatch(params)
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
    rescue => e
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 403
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present?
    end

    def self.name
      return 'Misskey'
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Misskey::AccessToken.order(Sequel.desc(:createdAt)).all do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
