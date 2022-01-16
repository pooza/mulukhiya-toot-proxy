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
      dest = File.join('/', @params[:prefix], "#{Time.now.strftime('%Y%m%d-%H%M%S')}.md")
      return upload(dest, params[:body])
    rescue => e
      raise Ginseng::GatewayError, "Nextcloud upload error (#{e.message})", e.backtrace
    end

    def upload(path, payload)
      path = File.join(@http.base_uri.path, 'remote.php/dav/files', @params[:user], path)
      return RestClient::Request.new(
        url: create_uri(path).to_s,
        method: :put,
        headers: {'Authorization' => HTTP.create_basic_auth(@params[:user], @params[:password])},
        payload:,
      ).execute
    end
  end
end
