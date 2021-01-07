module Mulukhiya
  class PleromaController < MastodonController
    post '/api/v1/pleroma/chats/:chat_id/messages' do
      @reporter.tags.clear
      params[status_field] = params[config['/pleroma/chat/field']]
      Event.new(:pre_chat, {reporter: @reporter, sns: @sns}).dispatch(params)
      params[config['/pleroma/chat/field']] = params[status_field]
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

    post '/api/v1/media' do
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

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Pleroma::AccessToken.order(Sequel.desc(:inserted_at)).all do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
