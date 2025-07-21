module Mulukhiya
  class PiefedClipper < piefedClipper
    def initialize(params = {})
      super
      @api_version = 'alpha'
    end

    def login
      return if @jwt
      response = http.post("/api/#{@api_version}/user/login", {
        body: {username:, password:},
      })
      @jwt = response['jwt']
    rescue => e
      raise Ginseng::AuthError, e.message, e.backtrace
    end
  end
end
