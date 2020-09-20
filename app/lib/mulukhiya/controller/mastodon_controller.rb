module Mulukhiya
  class MastodonController < Controller
    include ControllerMethods

    before do
      if params[:token].present? && home?
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif @headers['Authorization']
        @sns.token = @headers['Authorization'].split(/\s+/).last
      else
        @sns.token = nil
      end
    end

    post '/api/v1/statuses' do
      tags = TootParser.new(params[:status]).tags
      Event.new(:pre_toot, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.toot(params)
      notify(@reporter.response.parsed_response) if response_error?
      Event.new(:post_toot, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.message['tags']&.select! {|v| tags.member?(v['name'])}
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post %r{/api/v([12])/media} do
      Event.new(:pre_upload, {reporter: @reporter, sns: @sns}).dispatch(params)
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        version: media_api_default_version || params[:captures].first.to_i,
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

    put '/api/v1/media/:id' do
      if params[:thumbnail]
        Event.new(:pre_thumbnail, {reporter: @reporter, sns: @sns}).dispatch(params)
        @reporter.response = @sns.update_media(params[:id], params)
        Event.new(:post_thumbnail, {reporter: @reporter, sns: @sns}).dispatch(params)
      else
        @reporter.response = @sns.update_media(params[:id], params)
      end
      @renderer.message = JSON.parse(@reporter.response.body)
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      notify(@renderer.message)
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/favourite' do
      @reporter.response = @sns.fav(params[:id])
      Event.new(:post_fav, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      @reporter.response = @sns.boost(params[:id])
      Event.new(:post_boost, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/bookmark' do
      @reporter.response = @sns.bookmark(params[:id])
      Event.new(:post_bookmark, {reporter: @reporter, sns: @sns}).dispatch(params)
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    get '/api/v2/search' do
      params[:limit] = @config['/mastodon/search/limit']
      @reporter.response = @sns.search(params[:q], params)
      message = @reporter.response.parsed_response
      if message.is_a?(Hash)
        message.deep_stringify_keys!
        Event.new(:post_search, {reporter: @reporter, sns: @sns, message: message}).dispatch(params)
        @renderer.message = message
      else
        body = Nokogiri::HTML.parse(message, nil, 'utf-8')
        @renderer.message = {path: request.path, error: body.xpath('//h1').first.inner_text.chomp}
        Slack.broadcast(@renderer.message)
        message.each_line {|line| @logger.error(line.chomp)}
      end
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/mulukhiya/auth' do
      @renderer = SlimRenderer.new
      errors = MastodonAuthContract.new.exec(params)
      if errors.present?
        @renderer.template = 'auth'
        @renderer[:errors] = errors
        @renderer[:oauth_url] = @sns.oauth_uri
        @renderer.status = 422
      else
        @renderer.template = 'auth_result'
        r = @sns.auth(params[:code])
        if r.code == 200
          @sns.token = r.parsed_response['access_token']
          @sns.account.config.webhook_token = @sns.token
          @renderer[:hook_url] = @sns.account.webhook&.uri
        end
        @renderer[:status] = r.code
        @renderer[:result] = r.parsed_response
        @renderer.status = r.code
      end
      return @renderer.to_s
    end

    post '/mulukhiya/filter' do
      Handler.create('filter_command').handle_toot(params, {sns: @sns})
      @renderer.message = {filters: @sns.filters}
      return @renderer.to_s
    end

    def media_api_default_version
      return @config['/mastodon/media_api/version']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.name
      return 'Mastodon'
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Postgres.instance.exec('webhook_tokens').each do |row|
        token = Mastodon::AccessToken[row['id']]
        yield token.to_h if token.valid?
      end
    end
  end
end
