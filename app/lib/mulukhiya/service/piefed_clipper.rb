module Mulukhiya
  class PiefedClipper < piefedClipper
    API_VERSION = 'alpha'

    def login
      return if @jwt
      response = http.post("/api/#{API_VERSION}/user/login", {
        body: {username:, password:},
      })
      @jwt = response['jwt']
    rescue => e
      raise Ginseng::AuthError, e.message, e.backtrace
    end
  end
end
