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
          raise payload['error'] if payload['error']
          unless send("handle_#{payload['op']}".underscore.to_sym, payload['data'], body)
            EM.stop_event_loop
          end
        rescue => e
          logger.error(error: e.message)
          raise Ginseng::GatewayError, e.message, e.backtrace
        end
      end
    end

    private

    def login
      client.send({op: 'Login', data: {
        username_or_email: @params[:user],
        password: @params[:password],
      }}.to_json)
    end

    def post(body, jwt)
      data = {nsfw: false, community_id: @params[:community], auth: jwt}
      data[:name] = body[:name].to_s if body[:name]
      if uri = Controller.create_status_uri(body[:url])
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= uri.to_s
      end
      client.send({op: 'CreatePost', data: data}.to_json)
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
