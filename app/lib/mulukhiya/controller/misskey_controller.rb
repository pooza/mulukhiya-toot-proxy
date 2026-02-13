module Mulukhiya
  class MisskeyController < Controller
    include ControllerMethods

    post '/api/notes/create' do
      params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym] if quote?
      params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.note(params)
      Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/notes/drafts/create' do
      params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym] if quote?
      params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      Event.new(:pre_draft, {reporter:, sns:}).dispatch(params) unless renote?
      reporter.response = sns.draft(params)
      Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post '/api/notes/drafts/update' do
      if params[:text].present?
        if quote?
          params[visibility_field] = status_class[params[:renoteId]][visibility_field.to_sym]
        end
        params[visibility_field] = self.class.visibility_name(:unlisted) if channel?
      end
      reporter.response = sns.update_draft(params)
      if params[:text].present?
        Event.new(renote? ? :post_boost : :post_toot, {reporter:, sns:}).dispatch(params)
      end
      @renderer.message = reporter.response.parsed_response
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
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return @headers['HTTP_AUTHORIZATION'].split(/\s+/).last if @headers['HTTP_AUTHORIZATION']
      return params[:i]
    end
  end
end
