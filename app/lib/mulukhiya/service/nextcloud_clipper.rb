require 'base64'

module Mulukhiya
  class NextcloudClipper
    include Package

    def initialize(params)
      @params = params.deep_symbolize_keys
      @http = HTTP.new
      @http.base_uri = @params[:url]
    end

    def create_uri(href)
      return @http.create_uri(href)
    end

    def clip(params)
      params = {body: params.to_s} unless params.is_a?(Enumerable)
      return upload("/mulukhiya/#{Time.now.strftime('%Y%m%d-%H%M%S')}.md", params[:body])
    rescue => e
      raise Ginseng::GatewayError, "Nextcloud upload error (#{e.message})", e.backtrace
    end

    def upload(path, payload)
      path = File.join(@http.base_uri.path, 'remote.php/dav/files', @params[:user], path)
      return RestClient::Request.new(
        url: create_uri(path).to_s,
        method: :put,
        headers: {
          'Authorization' => "Basic #{Base64.encode64("#{@params[:user]}:#{@params[:password]}")}"
        },
        payload: payload,
      ).execute
    end
  end
end
