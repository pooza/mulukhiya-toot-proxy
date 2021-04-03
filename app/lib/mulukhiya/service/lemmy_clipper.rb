require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class LemmyClipper
    include Package
    attr_reader :uri, :client

    def initialize(params = {})
      @params = params
      @uri = Ginseng::URI.parse("wss://#{@params[:host]}/api/v2/ws")
      @client = Faye::WebSocket::Client.new(uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
      })
    end

    def clip(body)
      EM.run do
        client.send({op: 'Login', data: login_data}.to_json)

        client.on(:close) do |e|
          EM.stop_event_loop
        end

        client.on(:error) do |e|
          @response = e
          logger.error(error: e.message)
        end

        client.on(:message) do |message|
          payload = JSON.parse(message.data)
          @response = send("handle_#{payload['op']}".underscore.to_sym, payload['data'], body)
        rescue => e
          logger.error(error: e.message)
          EM.stop_event_loop
        end
      end
      return @response
    end

    def handle_login(payload, body)
      @auth = payload['jwt']
      return client.send({op: 'CreatePost', data: create_post_data(body)}.to_json)
    end

    private

    def login_data
      return {
        username_or_email: @params['user_id'],
        password: @params['password'].decrypt,
      }
    end

    def create_post_data(body)
      params = body[:template].params.deep_symbolize_keys
      source = params[:source] || params[:feed]
      return {
        name: (params[:entry]&.title || params[:status]),
        url: params[:entry]&.uri&.to_s,
        nsfw: false,
        community_id: source['/dest/lemmy/community_id'],
        auth: @auth,
      }
    end
  end
end
