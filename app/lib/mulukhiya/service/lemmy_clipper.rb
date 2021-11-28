require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class LemmyClipper
    include Package
    include SNSMethods

    def initialize(params = {})
      @params = params
    end

    def client
      @client ||= Faye::WebSocket::Client.new(uri.to_s, [], {
        tls: {
          verify_peer: verify_peer?,
        },
        ping: keepalive,
      })
      return @client
    end

    def uri
      unless @uri
        @uri = Ginseng::URI.parse("wss://#{@params[:host]}")
        @uri.path = config['/lemmy/urls/api']
      end
      return @uri
    end

    def keepalive
      return config['/websocket/keepalive']
    end

    def verify_peer?
      return config['/lemmy/verify_peer']
    end

    def clip(body)
      listen(method: :post, body: body)
    end

    def communities
      listen(method: :fetch_communities)
      return @communities
    end

    private

    def listen(params = {})
      EM.run do
        login

        client.on(:error) do |e|
          raise e.message
        end

        client.on(:message) do |message|
          payload = JSON.parse(message.data)
          raise payload['error'] if payload['error']
          method = "handle_#{payload['op']}".underscore.to_sym
          EM.stop_event_loop if send(method, payload['data'], params) == :stop
        end
      rescue => e
        logger.error(error: e, websocket: uri.to_s)
        EM.stop_event_loop
      end
    end

    def handle_login(payload, params = {})
      @jwt = payload['jwt']
      send(params[:method], params[:body])
    end

    def handle_create_post(payload, params = {})
      return :stop
    end

    def handle_list_communities(payload, params = {})
      @communities = payload['communities'].select {|c| c['subscribed']}
        .map {|c| [c.dig('community', 'id'), c.dig('community', 'title')]}.sort.to_h
      return :stop
    end

    def username
      return @params[:user]
    end

    def password
      return @params[:password].decrypt rescue @params[:password]
    end

    def login
      client.send({op: 'Login', data: {
        username_or_email: username,
        password: password,
      }}.to_json)
    end

    def post(body = {})
      body.deep_symbolize_keys!
      data = {nsfw: false, community_id: @params[:community], auth: @jwt}
      data[:name] = body[:name].to_s if body[:name]
      if uri = create_status_uri(body[:url])
        raise Ginseng::RequestError, "URI #{uri} invalid" unless uri.valid?
        raise Ginseng::RequestError, "URI #{uri} not puclic" unless uri.public?
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= uri.to_s
      end
      client.send({op: 'CreatePost', data: data}.to_json)
    end

    def fetch_communities(body = {})
      client.send({op: 'ListCommunities', data: {
        limit: config['/lemmy/communities/limit'],
        auth: @jwt,
      }}.to_json)
    end
  end
end
