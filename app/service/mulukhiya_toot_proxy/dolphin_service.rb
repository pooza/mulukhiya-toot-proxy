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

    def create_uri(href = '/api/notes/create')
      uri = self.uri.clone
      uri.path = href
      return uri
    end

    def self.create_tag(word)
      return '#' + word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
    end

    def self.message_field
      return Config.instance['/dolphin/message/field']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/message/visibility_name/#{name}"]
    end
  end
end
