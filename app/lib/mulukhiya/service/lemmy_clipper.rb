module Mulukhiya
  class LemmyClipper
    include Package
    include SNSMethods
    attr_reader :http
    API_VERSION = 'v3'

    def initialize(params = {})
      @params = params.deep_symbolize_keys
      @http = HTTP.new
      @http.base_uri = uri
      logger.info(clipper: self.class.to_s, method: __method__, url: uri.to_s)
    end

    def uri
      @uri ||= Ginseng::URI.parse("https://#{Ginseng::URI.parse(@params[:url]).host}")
      return @uri
    end

    def username
      return @params[:user]
    end

    def password
      return @params[:password].decrypt rescue @params[:password]
    end

    def login
      return if @jwt
      response = http.post("/api/#{API_VERSION}/user/login", {
        body: {
          username_or_email: username,
          password:,
        },
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
      data = {community_id: @params[:community], name: body[:name]&.to_s}
      if uri = create_status_uri(body[:url])
        raise Ginseng::RequestError, "URI #{uri} invalid" unless uri.valid?
        raise Ginseng::RequestError, "URI #{uri} not public" unless uri.public?
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= "via: #{uri}"
      end
      data[:name] = data[:name].gsub(/[\r\n[:blank:]]/, ' ')
      return http.post("/api/#{API_VERSION}/post", {
        body: data,
        headers: {'Authorization' => "Bearer #{@jwt}"},
      })
    end

    def communities
      login unless @jwt
      uri = self.uri.clone
      uri.path = "/api/#{API_VERSION}/community/list"
      uri.query_values = {
        limit: config['/lemmy/communities/limit'],
        type_: 'Subscribed',
        sort: 'New',
        page: 1,
      }
      communities = http.get(uri, {
        headers: {'Authorization' => "Bearer #{@jwt}"},
      })['communities'].map(&:deep_symbolize_keys)
      return communities.to_h {|v| [v.dig(:community, :id), v.dig(:community, :title)]}
    end
  end
end
