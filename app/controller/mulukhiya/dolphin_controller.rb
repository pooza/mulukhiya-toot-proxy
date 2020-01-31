module Mulukhiya
  class DolphinController < Controller
    before do
      @dolphin = DolphinService.new
      @dolphin.token = params[:i] if params[:i]
    end

    post '/api/notes/create' do
      Handler.exec_all(:pre_toot, params, {results: @results, sns: @dolphin}) unless renote?
      @results.response = @dolphin.note(params)
      @dolphin.account.slack&.say(@results.response.parsed_response) if response_error?
      Handler.exec_all(:post_toot, params, {results: @results, sns: @dolphin}) unless renote?
      @renderer.message = @results.response.parsed_response
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {error: e.message}
      @dolphin.account.slack&.say('error' => e.message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    post '/api/drive/files/create' do
      Handler.exec_all(:pre_upload, params, {results: @results, sns: @dolphin})
      @results.response = @dolphin.upload(params[:file][:tempfile].path)
      @dolphin.account.slack&.say(@results.response.parsed_response) if response_error?
      Handler.exec_all(:post_upload, params, {results: @results, sns: @dolphin})
      @renderer.message = JSON.parse(@results.response.body)
      @renderer.status = @results.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = JSON.parse(e.response.body)
      @dolphin.account.slack&.say('error' => e.message)
      @renderer.status = e.response.code
      return @renderer.to_s
    end

    post '/api/notes/favorites/create' do
      @results.response = @dolphin.fav(params[:noteId])
      Handler.exec_all(:post_bookmark, params, {results: @results, sns: @dolphin})
      @renderer.message = @results.response.parsed_response || {}
      @renderer.status = @results.response.code
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

    def renote?
      return params[:text].nil?
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

    def self.attachment_key
      return Config.instance['/dolphin/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/status/visibility_names/#{name}"]
    end

    def self.events
      return Config.instance['/dolphin/events'].map(&:to_sym)
    end
  end
end
