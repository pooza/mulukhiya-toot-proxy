module Mulukhiya
  class MastodonController < Controller
    before do
      @sns = MastodonService.new
      if params[:token].present? && request.path.match?(%r{/(mulukhiya|auth)})
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
    rescue ValidateError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post %r{/api/v([12])/media} do
      Handler.dispatch(:pre_upload, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        response: :raw,
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
      errors = MastodonAuthContract.new.call(params).errors.to_h
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

    def self.parser_class
      return "Mulukhiya::#{Config.instance['/mastodon/parser'].camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{Config.instance['/mastodon/dbms'].camelize}".constantize
    end

    def self.postgres?
      return Config.instance['/mastodon/dbms'] == 'postgres'
    end

    def self.mongodb?
      return Config.instance['/mastodon/dbms'] == 'mongodb'
    end

    def self.status_field
      return Config.instance['/mastodon/status/field']
    end

    def self.status_key
      return Config.instance['/mastodon/status/key']
    end

    def self.poll_options_field
      return Config.instance['/mastodon/poll/options/field']
    end

    def self.attachment_key
      return Config.instance['/mastodon/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/mastodon/status/visibility_names/#{name}"]
    end

    def self.status_label
      return Config.instance['/mastodon/status/label']
    end

    def self.events
      return Config.instance['/mastodon/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      config = Config.instance
      Postgres.instance.exec('webhook_tokens').each do |row|
        values = {
          digest: Webhook.create_digest(config['/mastodon/url'], row['token']),
          sha1_digest: Webhook.create_sha1_digest(config['/mastodon/url'], row['token']),
          token: row['token'],
          account: Environment.account_class[row['account_id']],
        }
        yield values
      end
    end
  end
end
