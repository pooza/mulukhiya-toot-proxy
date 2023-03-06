module Mulukhiya
  class PleromaController < MastodonController
    put '/api/:version/pleroma/statuses/:status_id/reactions/:emoji' do
      reporter.response = sns.reaction(params[:status_id], params[:emoji])
      Event.new(:post_reaction, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    delete '/api/:version/pleroma/statuses/:status_id/reactions/:emoji' do
      reporter.response = sns.delete_reaction(params[:status_id], params[:emoji])
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/:version/pleroma/chats/:chat_id/messages' do
      Event.new(:pre_chat, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.say(params)
      Event.new(:post_chat, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/:version/media' do
      filename = params[:name]
      Event.new(:pre_upload, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.upload(params.dig(:file, :tempfile), {filename:})
      Event.new(:post_upload, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end
  end
end
