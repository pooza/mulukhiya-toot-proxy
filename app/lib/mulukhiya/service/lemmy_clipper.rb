module Mulukhiya
  class LemmyClipper
    include Package
    include SNSMethods
    attr_reader :http

    def initialize(params = {})
      @params = params.deep_symbolize_keys
      @http = HTTP.new
      @http.base_uri = uri
      login
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
      response = http.post('/api/v3/user/login', {
        body: {
          username_or_email: username,
          password:,
        },
      })
      @jwt = response['jwt']
    end

    def clip(body)
      body ||= {}
      body.deep_symbolize_keys!
      raise Ginseng::AuthError, 'invalid jwt' unless @jwt
      raise Ginseng::RequestError, 'invalid community' unless @params[:community]
      data = {community_id: @params[:community], auth: @jwt, name: body[:name]&.to_s}
      if uri = create_status_uri(body[:url])
        raise Ginseng::RequestError, "URI #{uri} invalid" unless uri.valid?
        raise Ginseng::RequestError, "URI #{uri} not public" unless uri.public?
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= "via: #{uri}"
      end
      return http.post('/api/v3/post', {body: data})
    end

    def communities
      raise Ginseng::AuthError, 'invalid jwt' unless @jwt
      uri = self.uri.clone
      uri.path = '/api/v3/community/list'
      uri.query_values = {
        limit: config['/lemmy/communities/limit'],
        auth: @jwt,
        type_: 'Subscribed',
        sort: 'New',
        page: 1,
      }
      communities = http.get(uri)['communities'].map(&:deep_symbolize_keys)
      return communities.to_h {|v| [v.dig(:community, :id), v.dig(:community, :title)]}
    end
  end
end
