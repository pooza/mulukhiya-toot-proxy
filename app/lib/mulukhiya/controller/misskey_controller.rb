module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    post '/api/notes/create' do
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.note(params)
      Event.new(:post_toot, {reporter:, sns:}).dispatch(params) unless renote?
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      notify(error: e.raw_message)
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/messaging/messages/create' do
      reporter.tags.clear
      Event.new(:pre_chat, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.say(params)
      Event.new(:post_chat, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      notify(error: e.raw_message)
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Event.new(:pre_upload, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.upload(params.dig(:file, :tempfile), {
        filename: params.dig(:file, :filename),
      })
      Event.new(:post_upload, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      e.alert
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      notify(@renderer.message)
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      reporter.response = sns.fav(params[:noteId])
      Event.new(:post_bookmark, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response || {}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present?
    end

    def token
      return params[:i]
    end
  end
end
