require 'eventmachine'
require 'faye/websocket'

module Mulukhiya
  class LemmyClipper
    include Package

    def initialize(params = {})
      @params = params
    end

    def uri
      unless @uri
        @uri = Ginseng::URI.parse("wss://#{@params[:host]}")
        @uri.path = config['/lemmy/urls/api']
      end
      return @uri
    end

    def client
      @client ||= Faye::WebSocket::Client.new(uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
      })
      return @client
    end

    def clip(body)
      EM.run do
        login

        client.on(:close) do |e|
          EM.stop_event_loop
        end

        client.on(:error) do |e|
          raise Ginseng::GatewayError, e.message
        end

        client.on(:message) do |message|
          payload = JSON.parse(message.data)
          unless send("handle_#{payload['op']}".underscore.to_sym, payload['data'], body)
            EM.stop_event_loop
          end
        rescue => e
          logger.error(e)
          EM.stop_event_loop
        end
      end
    end

    private

    def login
      client.send({op: 'Login', data: {
        username_or_email: @params[:user_id],
        password: @params[:password],
      }}.to_json)
    end

    def post(body, jwt)
      client.send({op: 'CreatePost', data: {
        name: body[:name].to_s,
        # url: body[:uri].to_s,
        nsfw: false,
        community_id: @params[:community_id],
        auth: jwt,
      }}.to_json)
    end

    def handle_login(payload, body)
      post(body, payload['jwt'])
      return true
    end

    def handle_create_post(payload, body)
      return nil
    end
  end
end
