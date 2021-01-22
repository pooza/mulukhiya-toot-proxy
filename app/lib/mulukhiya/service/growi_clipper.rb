module Mulukhiya
  class GrowiClipper
    GRANT_PUBLIC = 1
    GRANT_RESTRICTED = 2
    GRANT_SPECIFIED = 3
    GRANT_OWNER = 4

    def initialize(params = {})
      @token = params[:token]
      @prefix = params[:prefix]
      @http = HTTP.new
      @http.base_uri = params[:uri]
    end

    def clip(params)
      params[:access_token] ||= @token
      params[:grant] ||= GRANT_OWNER
      params[:path] ||= File.join(@prefix, Time.now.strftime('%Y/%m/%d/%H%M%S%L'))
      response = @http.post('/_api/pages.create', {body: params})
      raise Ginseng::GatewayError, response['error'] unless response&.dig('ok')
      return response
    end
  end
end
