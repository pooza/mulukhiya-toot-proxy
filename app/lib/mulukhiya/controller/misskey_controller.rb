module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    post '/api/notes/create' do
      params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym] if quote?
      params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.note(params)
      Event.new((renote? ? :post_boost : :post_toot), {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
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

    post '/api/notes/favorites/create' do
      reporter.response = sns.fav(params[:noteId])
      Event.new(:post_bookmark, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response || {}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/notes/reactions/create' do
      reporter.response = sns.reaction(params[:noteId], params[:reaction])
      Event.new(:post_reaction, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response || {}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    def renote?
      return params[:renoteId].present? && params[:text].empty?
    end

    def quote?
      return params[:renoteId].present? && params[:text].present?
    end

    def channel?
      return params[:channelId].present?
    end

    def token
      return params[:i]
    end
  end
end
