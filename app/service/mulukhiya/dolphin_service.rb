module Mulukhiya
  class DolphinService
    include Package
    attr_reader :uri
    attr_accessor :token
    attr_accessor :mulukhiya_enable

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/test/token']
      @uri = DolphinURI.parse(uri || @config['/dolphin/url'])
      @mulukhiya_enable = false
      @http = http_class.new
    end

    def mulukhiya_enable?
      return @mulukhiya_enable || false
    end

    alias mulukhiya? mulukhiya_enable?

    def account
      @account ||= Environment.account_class.get(token: @token)
      return @account
    rescue
      return nil
    end

    def note(body, params = {})
      body = {text: body.to_s} unless body.is_a?(Hash)
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      body[:i] ||= @token
      return @http.post(create_uri, {body: body.to_json, headers: headers})
    end

    def favourite(id, params = {})
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post(create_uri('/api/notes/favorites/create'), {
        body: {noteId: id, i: @token}.to_json,
        headers: headers,
      })
    end

    alias fav favourite

    def upload(path, params = {})
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      body = {force: 'true', i: @token}
      return @http.upload(create_uri('/api/drive/files/create'), path, headers, body)
    end

    def upload_remote_resource(uri)
      path = File.join(
        Environment.dir,
        'tmp/media',
        Digest::SHA1.hexdigest(uri),
      )
      File.write(path, @http.get(uri))
      return upload(path)
    ensure
      File.unlink(path) if File.exist?(path)
    end

    def fetch_note(id)
      return @http.get(create_uri("/mulukhiya/note/#{id}")).parsed_response
    end

    def create_uri(href = '/api/notes/create')
      uri = self.uri.clone
      uri.path = href
      return uri
    end

    def self.create_tag(word)
      return '#' + word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
    end
  end
end
