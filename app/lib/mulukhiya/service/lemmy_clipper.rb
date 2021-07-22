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
      @client ||= Faye::WebSocket::Client.new(uri.to_s, nil, {
        ping: config['/websocket/keepalive'],
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

    def handle_login(payload, body)
      @jwt = payload['jwt']
      post(body)
    end

    def handle_create_post(payload, body)
      return :stop
    end

    def clip(body)
      EM.run do
        login

        client.on(:close) do |e|
          EM.stop_event_loop
        end

        client.on(:error) do |e|
          logger.error(error: e.message)
          EM.stop_event_loop
        end

        client.on(:message) do |message|
          payload = JSON.parse(message.data)
          raise payload['error'] if payload['error']
          method = "handle_#{payload['op']}".underscore.to_sym
          EM.stop_event_loop if send(method, payload['data'], body) == :stop
        rescue => e
          logger.error(error: e)
          EM.stop_event_loop
        end
      end
    end

    private

    def login
      client.send({op: 'Login', data: {
        username_or_email: @params[:user],
        password: (@params[:password].decrypt rescue @params[:password]),
      }}.to_json)
    end

    def post(body)
      data = {nsfw: false, community_id: @params[:community], auth: @jwt}
      data[:name] = body[:name].to_s if body[:name]
      if uri = create_status_uri(body[:url])
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= uri.to_s
      end
      client.send({op: 'CreatePost', data: data}.to_json)
    end
  end
end
