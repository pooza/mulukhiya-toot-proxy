module Mulukhiya
  class MastodonController < Controller
    include ControllerMethods

    post '/api/v1/statuses' do
      tags = TootParser.new(params[:status]).tags
      Event.new(:pre_toot, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.toot(params)
      Event.new(:post_toot, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.message['tags']&.select! {|v| tags.member?(v['name'])}
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      e.alert
      @renderer.message = {error: e.message}
      @renderer.status = e.source_status
      return @renderer.to_s
    end

    post %r{/api/v([12])/media} do
      Event.new(:pre_upload, {reporter:, sns:}).dispatch(params)
      reporter.response = sns.upload(params.dig(:file, :tempfile), {
        version: params[:captures].first.to_i,
        filename: params.dig(:file, :filename),
      })
      Event.new(:post_upload, {reporter:, sns:}).dispatch(params)
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      e.alert
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    put '/api/v1/media/:id' do
      Event.new(:pre_thumbnail, {reporter:, sns:}).dispatch(params) if params[:thumbnail]
      reporter.response = sns.update_media(params[:id], params)
      Event.new(:post_thumbnail, {reporter:, sns:}).dispatch(params) if params[:thumbnail]
      @renderer.message = JSON.parse(reporter.response.body)
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      e.alert
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/favourite' do
      reporter.response = sns.fav(params[:id])
      Event.new(:post_fav, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      reporter.response = sns.boost(params[:id])
      Event.new(:post_boost, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/bookmark' do
      reporter.response = sns.bookmark(params[:id])
      Event.new(:post_bookmark, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    end

    get '/api/v2/search' do
      params[:limit] = config['/mastodon/search/limit']
      reporter.response = sns.search(params[:q], params)
      message = reporter.response.parsed_response
      if message.is_a?(Hash)
        message.deep_stringify_keys!
        Event.new(:post_search, {reporter:, sns:, message:}).dispatch(params)
        @renderer.message = message
      else
        @renderer.message = {
          path: request.path,
          error: message.nokogiri.xpath('//h1').first.inner_text.chomp,
        }
      end
      @renderer.status = reporter.response.code
      return @renderer.to_s
    end

    def token
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return nil
    end
  end
end
