module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    post '/api/notes/create' do
      Event.new(:pre_toot, {reporter: @reporter, sns: @sns}).dispatch(params) unless renote?
      params.delete(status_field) if params[status_field].empty?
      @reporter.response = @sns.note(params)
      Event.new(:post_toot, {reporter: @reporter, sns: @sns}).dispatch(params) unless renote?
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/messaging/messages/create' do
      @reporter.tags.clear
      Event.new(:pre_chat, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.say(params)
      Event.new(:post_chat, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Event.new(:pre_upload, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        filename: params[:file][:filename],
      })
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
      Event.new(:post_bookmark, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response || {}
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present?
    end

    def token
      return params[:i] if params[:i]
      raise Ginseng::AuthError, 'Unauthorized'
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Misskey::AccessToken.order(Sequel.desc(:createdAt)).all do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
