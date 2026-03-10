module Mulukhiya
  class PiefedClipper
    include Package
    include SNSMethods

    attr_reader :http

    def initialize(params = {})
      @params = params.deep_symbolize_keys
      @http = HTTP.new
      @http.base_uri = uri
      logger.info(clipper: self.class.to_s, method: __method__, url: uri.to_s)
    end

    def api_version
      return config['/service/piefed/api/version']
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
        data[:title] ||= uri.subject.ellipsize(config['/service/piefed/subject/max_length'])
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
      communities = []
      uri = self.uri.clone
      uri.path = "/api/#{api_version}/community/list"
      config['/service/piefed/community/types'].each do |type_|
        page = 1
        loop do
          uri.query_values = {type_:, page:}
          response = http.get(uri, {headers: {'Authorization' => "Bearer #{@jwt}"}})
          communities.concat(response['communities'])
          break unless response['next_page']
          page += 1
        end
      end
      return communities.to_h {|v| [v.dig('community', 'id').to_i, v.dig('community', 'title')]}
    end
  end
end
