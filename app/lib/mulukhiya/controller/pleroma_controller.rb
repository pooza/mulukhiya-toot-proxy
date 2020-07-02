module Mulukhiya
  class PleromaController < Controller
    before do
      @sns = PleromaService.new
      if params[:token].present? && request.path.match?(%r{/(mulukhiya|auth)})
        @sns.token = Crypt.new.decrypt(params[:token])
      elsif @headers['Authorization']
        @sns.token = @headers['Authorization'].split(/\s+/).last
      else
        @sns.token = nil
      end
    end

    post '/api/v1/statuses' do
      Handler.dispatch(:pre_toot, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.post(params)
      notify(@reporter.response.parsed_response) if response_error?
      Handler.dispatch(:post_toot, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue ValidateError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/v1/media' do
      Handler.dispatch(:pre_upload, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        response: :raw,
        filename: params[:file][:filename],
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

    post '/api/v1/statuses/:id/bookmark' do
      @reporter.response = @sns.bookmark(params[:id])
      Handler.dispatch(:post_bookmark, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    end

    post '/mulukhiya/auth' do
      @renderer = SlimRenderer.new
      errors = PleromaAuthContract.new.call(params).errors.to_h
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

    def self.name
      return 'Pleroma'
    end

    def self.webhook?
      return true
    end

    def self.clipping?
      return true
    end

    def self.announcement?
      return false
    end

    def self.filter?
      return false
    end

    def self.parser_class
      return "Mulukhiya::#{Config.instance['/pleroma/parser'].camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{Config.instance['/pleroma/dbms'].camelize}".constantize
    end

    def self.postgres?
      return Config.instance['/pleroma/dbms'] == 'postgres'
    end

    def self.mongodb?
      return Config.instance['/pleroma/dbms'] == 'mongodb'
    end

    def self.status_field
      return Config.instance['/pleroma/status/field']
    end

    def self.status_key
      return Config.instance['/pleroma/status/key']
    end

    def self.poll_options_field
      return Config.instance['/pleroma/poll/options/field']
    end

    def self.attachment_key
      return Config.instance['/pleroma/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/pleroma/status/visibility_names/#{name}"]
    end

    def self.status_label
      return Config.instance['/pleroma/status/label']
    end

    def self.events
      return Config.instance['/pleroma/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      config = Config.instance
      Pleroma::AccessToken.all do |token|
        next unless token.account
        next unless token.token
        values = {
          digest: Webhook.create_digest(config['/pleroma/url'], token.token),
          token: token.token,
          account: token.account,
        }
        yield values
      end
    end
  end
end
