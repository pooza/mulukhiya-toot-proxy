require 'sinatra'
require 'active_support'
require 'active_support/core_ext'
require 'mulukhiya-toot-proxy/config'
require 'mulukhiya-toot-proxy/slack'
require 'mulukhiya-toot-proxy/package'
require 'httparty'
require 'addressable/uri'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/json_renderer'

module MulukhiyaTootProxy
  class Application < Sinatra::Base
    def initialize
      super
      @config = Config.instance
      @logger = Logger.new
      @logger.info({
        message: 'starting...',
        server: {port: @config['thin']['port']},
      })
    end

    before do
      @message = {request: {path: request.path, params: params}, response: {}}
      @renderer = JSONRenderer.new
      if request.request_method == 'POST'
        @json = JSON.parse(request.body.read.to_s)
        @message[:request][:params] = @json
      end
    end

    after do
      @message[:response][:status] ||= @renderer.status
      if @renderer.status < 400
        @logger.info(@message)
      else
        @logger.error(@message)
      end
      status @renderer.status
      content_type @renderer.type
    end

    get '/about' do
      @message[:response][:message] = Package.full_name
      @renderer.message = @message
      return @renderer.to_s
    end

    post '/api/v1/statuses' do
      headers = request.env.select { |k, v| k.start_with?('HTTP_')}
      url = Addressable::URI.parse('https://st.mstdn.b-shock.org/api/v1/statuses')
      api_response = HTTParty.post(url, {
        body: @json.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => headers['HTTP_USER_AGENT'],
          'Authorization' => "Bearer #{headers['HTTP_AUTHORIZATION'].split(/\s+/)[1]}",
          'X-Mulukhiya' => 'rewrited',
        },
      })
      @message[:response][:text] = @json['status']
      @message.merge!(JSON.parse(api_response.to_s))
      @renderer.message = @message
      return @renderer.to_s
    end

    not_found do
      @renderer = JSONRenderer.new
      @renderer.status = 404
      @message[:response][:message] = "Resource #{@message[:request][:path]} not found."
      @renderer.message = @message
      return @renderer.to_s
    end

    error do
      @renderer = JSONRenderer.new
      @renderer.status = 500
      @message[:response][:message] = env['sinatra.error'].message
      @renderer.message = @message
      Slack.all.map{ |h| h.say(@message)}
      return @renderer.to_s
    end
  end
end
