module Mulukhiya
  class GrowiClipper
    include Package
    GRANT_PUBLIC = 1
    GRANT_RESTRICTED = 2
    GRANT_SPECIFIED = 3
    GRANT_OWNER = 4

    def initialize(params = {})
      @token = (params[:token].decrypt rescue params[:token])
      @prefix = params[:prefix]
      @http = HTTP.new
      @http.base_uri = params[:uri]
    end

    def clip(params)
      params[:access_token] ||= @token
      params[:grant] ||= GRANT_OWNER
      params[:path] ||= File.join(@prefix, Time.now.strftime('%Y/%m/%d/%H%M%S%L'))
      response = @http.post(config['/growi/urls/create_page'], {body: params})
      return response if response['data']['page']
      raise Ginseng::GatewayError, 'Invalid response'
    end
  end
end
