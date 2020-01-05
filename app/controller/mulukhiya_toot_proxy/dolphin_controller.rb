module MulukhiyaTootProxy
  class DolphinController < Ginseng::Web::Sinatra
    include Package
    set :root, Environment.dir

    before do
      @results = ResultContainer.new
      @dolphin = DolphinService.new
      @dolphin.token = params[:i] if params[:i]
    end

    post '/api/notes/create' do
      Handler.exec_all(:pre_toot, params, {results: @results, sns: @dolphin})
      @results.response = @dolphin.note(params)
      Handler.exec_all(:post_toot, params, {results: @results, sns: @dolphin})
      @renderer.message = @results.response.parsed_response
      @renderer.message['results'] = @results.summary
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Handler.exec_all(:pre_upload, params, {results: @results, sns: @dolphin})
      @results.response = @dolphin.upload(params[:file][:tempfile].path)
      Handler.exec_all(:post_upload, params, {results: @results, sns: @dolphin})
      @renderer.message = JSON.parse(@results.response.body)
      @renderer.message['results'] = @results.summary
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = JSON.parse(e.response.body)
      @renderer.status = e.response.code
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      @results.response = @dolphin.fav(params[:noteId])
      Handler.exec_all(:post_bookmark, params, {results: @results, sns: @dolphin})
      @renderer.message = @results.response.parsed_response || {}
      @renderer.message['results'] = @results.summary
      @renderer.status = @results.response.code
      return @renderer.to_s
    end

    get '/mulukhiya' do
      @renderer = HTMLRenderer.new
      @renderer.template = 'home'
      return @renderer.to_s
    end

    get '/mulukhiya/about' do
      @renderer.message = package_class.full_name
      return @renderer.to_s
    end

    get '/mulukhiya/health' do
      @renderer.message = Environment.health
      @renderer.status = @renderer.message[:status] || 200
      return @renderer.to_s
    end

    get '/mulukhiya/note/:note' do
      note = Environment.status_class[params[:note]]
      if note.nil? || !note.visible?
        @renderer.status = 404
      else
        @renderer.message = note.to_h
        @renderer.message[:account] = Environment.account_class[note.userId].to_h
      end
      return @renderer.to_s
    end

    get '/mulukhiya/style/:style' do
      @renderer = CSSRenderer.new
      @renderer.template = params[:style]
      return @renderer.to_s
    rescue Ginseng::RenderError
      @renderer.status = 404
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer = default_renderer_class.new
      @renderer.status = e.status
      @renderer.message = e.to_h
      @renderer.message.delete(:backtrace)
      @renderer.message[:error] = e.message
      Slack.broadcast(e)
      @logger.error(e)
      return @renderer.to_s
    end

    def self.name
      return 'Dolphin'
    end

    def self.webhook?
      return false
    end

    def self.status_field
      return Config.instance['/dolphin/status/field']
    end

    def self.status_key
      return Config.instance['/dolphin/status/key']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/status/visibility_names/#{name}"]
    end

    def self.events
      return Config.instance['/dolphin/events'].map(&:to_sym)
    end
  end
end
