module Mulukhiya
  class PiefedClipper < LemmyClipper
    API_VERSION = 'alpha'.freeze

    def login
      return if @jwt
      response = http.post("/api/#{API_VERSION}/user/login", {
        body: {username:, password:},
      })
      @jwt = response['jwt']
    rescue => e
      raise Ginseng::AuthError, e.message, e.backtrace
    end

    def communities
      login unless @jwt
      uri = self.uri.clone
      uri.path = "/api/#{API_VERSION}/community/list"
      uri.query_values = {
        type_: 'Subscribed',
      }
      communities = http.get(uri, {
        headers: {'Authorization' => "Bearer #{@jwt}"},
      })['communities'].map(&:deep_symbolize_keys)
      return communities.to_h {|v| [v.dig(:community, :id), v.dig(:community, :title)]}
    end
  end
end
