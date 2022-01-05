module Mulukhiya
  class PleromaController < MastodonController
    post '/api/v1/pleroma/chats/:chat_id/messages' do
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

    post '/api/v1/media' do
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
  end
end
