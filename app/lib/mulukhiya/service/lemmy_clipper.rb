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

    def receive(message, body)
      payload = JSON.parse(message.data)
      raise payload['error'] if payload['error']
      method_name = create_method_name(payload['op'])
      logger.info(websocket: uri.to_s, method: method_name)
      return send(method_name.to_sym, payload, body)
    rescue NoMethodError
      logger.error(class: self.class.to_s, method: method_name, message: 'method undefined')
    rescue => e
      logger.error(error: e, payload: (payload rescue message.data))
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

        client.on(:error) do |e|
          raise e.message
        end

        client.on :message do |message|
          EM.stop_event_loop if receive(message, body) == :stop
        end
      rescue => e
        logger.error(error: e, websocket: uri.to_s)
        EM.stop_event_loop
      end
    end

    private

    def create_method_name(name)
      return "handle_#{name.gsub(/[^[:word:]]+/, '_')}".underscore
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

    def post(body)
      body.deep_symbolize_keys!
      data = {nsfw: false, community_id: @params[:community], auth: @jwt}
      data[:name] = body[:name].to_s if body[:name]
      if uri = create_status_uri(body[:url])
        raise Ginseng::RequestError "Invalid URI #{uri}" unless uri.valid?
        raise Ginseng::RequestError "Invalid URI #{uri}" unless uri.public?
        data[:url] = uri.to_s
        data[:name] ||= uri.subject.ellipsize(config['/lemmy/subject/max_length'])
        data[:body] ||= uri.to_s
      end
      client.send({op: 'CreatePost', data: data}.to_json)
    end
  end
end
