module Mulukhiya
  class NextcloudClipper
    include Package
    attr_reader :http

    def initialize(params)
      @params = params.deep_symbolize_keys
      @params[:password] = (@params[:password].decrypt rescue @params[:password])
      @params[:prefix] ||= File.join('/', Package.short_name)
      @http = HTTP.new
      @http.base_uri = @params[:url]
    end

    def ping
      @http.head(@http.base_uri.path)
      return true
    rescue => e
      e.log
      return false
    end

    def path_prefix
      return File.join(@http.base_uri.path, config['/nextcloud/urls/file'], @params[:user])
    end

    def create_uri(href)
      return @http.create_uri(File.join(path_prefix, href))
    end

    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Enumerable)
      params.deep_symbolize_keys!
      headers = {'Authorization' => HTTP.create_basic_auth(@params[:user], @params[:password])}
      uri = create_uri(File.join(@params[:prefix], "#{Time.now.strftime('%Y%m%d-%H%M%S')}.md"))
      dig(uri, {headers:})
      headers['Content-Type'] = MIMEType.type(uri.path)
      body = params[:body]
      return @http.put(uri, {headers:, body:})
    rescue => e
      raise Ginseng::GatewayError, "Nextcloud upload error (#{e.message})", e.backtrace
    end

    def dig(uri, params)
      path = uri.path.sub(Regexp.new("^#{Regexp.escape(path_prefix)}"), '')
      href = '/'
      File.dirname(path).split('/').each do |part|
        href = File.join(href, part)
        uri = create_uri(href)
        @http.get(uri, {headers: params[:headers]})
      rescue => e
        e.log(uri:)
        @http.mkcol(uri, {headers: params[:headers]})
      end
    end
  end
end
