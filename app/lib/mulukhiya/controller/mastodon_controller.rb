module Mulukhiya
  class MastodonController < Controller
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
      Handler.dispatch(:pre_toot, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.toot(params)
      notify(@reporter.response.parsed_response) if response_error?
      Handler.dispatch(:post_toot, params, {reporter: @reporter, sns: @sns})
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
      Handler.dispatch(:pre_upload, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        filename: params[:file][:filename],
        version: params[:captures].first.to_i,
      })
      Handler.dispatch(:post_upload, params, {reporter: @reporter, sns: @sns})
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
        Handler.dispatch(:pre_thumbnail, params, {reporter: @reporter, sns: @sns})
        @reporter.response = @sns.update_media(params[:id], params)
        Handler.dispatch(:post_thumbnail, params, {reporter: @reporter, sns: @sns})
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
      Handler.dispatch(:post_fav, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/reblog' do
      @reporter.response = @sns.boost(params[:id])
      Handler.dispatch(:post_boost, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/api/v1/statuses/:id/bookmark' do
      @reporter.response = @sns.bookmark(params[:id])
      Handler.dispatch(:post_bookmark, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    get '/api/v2/search' do
      params[:limit] = @config['/mastodon/search/limit']
      @reporter.response = @sns.search(params[:q], params)
      @message = @reporter.response.parsed_response.with_indifferent_access
      Handler.dispatch(:post_search, params, {reporter: @reporter, message: @message})
      @renderer.message = @message
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

    get '/feed/v1.0/tag/:tag' do
      @renderer = TagAtomFeedRenderer.new
      @renderer.tag = params[:tag]
      @renderer.status = 404 unless @renderer.exist?
      return @renderer.to_s
    end

    post '/mulukhiya/filter' do
      Handler.create('filter_command').handle_toot(params, {sns: @sns})
      @renderer.message = {filters: @sns.filters}
      return @renderer.to_s
    end

    def self.name
      return 'Mastodon'
    end

    def self.webhook?
      return true
    end

    def self.clipping?
      return true
    end

    def self.announcement?
      return true
    end

    def self.filter?
      return true
    end

    def self.livecure?
      return config['/webui/livecure']
    end

    def self.parser_class
      return "Mulukhiya::#{parser_name.camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{dbms_name.camelize}".constantize
    end

    def self.postgres?
      return dbms_name == 'postgres'
    end

    def self.mongo?
      return dbms_name == 'mongo'
    end

    def self.dbms_name
      return config['/mastodon/dbms']
    end

    def self.parser_name
      return config['/mastodon/parser']
    end

    def self.status_field
      return config['/mastodon/status/field']
    end

    def self.status_key
      return config['/mastodon/status/key']
    end

    def self.poll_options_field
      return config['/mastodon/poll/options/field']
    end

    def self.attachment_key
      return config['/mastodon/attachment/key']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return config['/mastodon/status/label']
    end

    def self.events
      return config['/mastodon/events'].map(&:to_sym)
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
