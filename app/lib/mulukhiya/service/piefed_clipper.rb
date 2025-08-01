module Mulukhiya
  class PiefedClipper < LemmyClipper
    def api_version
      return config['/piefed/api/version']
    end

    def login
      return if @jwt
      response = http.post("/api/#{api_version}/user/login", {
        body: {username:, password:},
      })
      @jwt = response['jwt']
    rescue => e
      raise Ginseng::AuthError, e.message, e.backtrace
    end

    def clip(body)
      login unless @jwt
      body ||= {}
      body.deep_symbolize_keys!
      raise Ginseng::RequestError, 'invalid community' unless @params[:community]
      data = {community_id: @params[:community], title: body[:name]&.to_s}
      if uri = create_status_uri(body[:url])
        raise Ginseng::RequestError, "URI #{uri} invalid" unless uri.valid?
        raise Ginseng::RequestError, "URI #{uri} not public" unless uri.public?
        data[:url] = uri.to_s
        data[:title] ||= uri.subject.ellipsize(config['/piefed/subject/max_length'])
        data[:body] ||= "via: #{uri}"
      end
      data[:title] = data[:title].gsub(/[\r\n[:blank:]]/, ' ')
      return http.post("/api/#{api_version}/post", {
        body: data,
        headers: {'Authorization' => "Bearer #{@jwt}"},
      })
    end

    def communities
      login unless @jwt
      uri = self.uri.clone
      uri.path = "/api/#{api_version}/community/list"
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
