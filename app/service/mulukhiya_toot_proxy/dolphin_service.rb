module MulukhiyaTootProxy
  class DolphinService
    include Package
    attr_reader :uri
    attr_accessor :token
    attr_accessor :mulukhiya_enable

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/test/token']
      @uri = URI.parse(uri || @config['/dolphin/url'])
      @mulukhiya_enable = false
      @http = http_class.new
    end

    def mulukhiya_enable?
      return @mulukhiya_enable || false
    end

    alias mulukhiya? mulukhiya_enable?

    def account
      return Environment.account_class.get(token: @token)
    end

    def note(body, params = {})
      body = {status: body.to_s} unless body.is_a?(Hash)
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
      r = @http.post(create_uri('/notes'), {body: {sinceId: id, limit: 1}.to_json})
      # Slack.broadcast(id: id, response: r.parsed_response)
      return r.first
    end

    def create_uri(href = '/api/notes/create')
      uri = self.uri.clone
      uri.path = href
      return uri
    end

    def self.create_tag(word)
      return '#' + word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
    end

    def self.name
      return 'Dolphin'
    end

    def self.message_field
      return Config.instance['/dolphin/message/field']
    end

    def self.message_key
      return Config.instance['/dolphin/message/key']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/message/visibility_name/#{name}"]
    end
  end
end
