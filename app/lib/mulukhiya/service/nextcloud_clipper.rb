module Mulukhiya
  class NextcloudClipper
    include Package

    def initialize(params)
      @params = params.deep_symbolize_keys
      @params[:password] = (@params[:password].decrypt rescue @params[:password])
      @params[:prefix] ||= File.join('/', Package.short_name)
      @http = HTTP.new
      @http.base_uri = @params[:url]
    end

    def create_uri(href)
      return @http.create_uri(href)
    end

    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Enumerable)
      params.deep_symbolize_keys!
      dest = File.join(@params[:prefix], "#{Time.now.strftime('%Y%m%d-%H%M%S')}.md")
      uri = create_uri(File.join(@http.base_uri.path, 'remote.php/dav/files', @params[:user], dest))
      return @http.put(uri, {
        headers: {
          'Authorization' => HTTP.create_basic_auth(@params[:user], @params[:password]),
          'Content-Type' => MIMEType.type(uri.path),
        },
        body: params[:body],
      })
    rescue => e
      raise Ginseng::GatewayError, "Nextcloud upload error (#{e.message})", e.backtrace
    end
  end
end
