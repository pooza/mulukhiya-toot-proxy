require 'sinatra'
require 'active_support'
require 'active_support/core_ext'
require 'mulukhiya-toot-proxy/config'
require 'mulukhiya-toot-proxy/slack'
require 'mulukhiya-toot-proxy/package'
require 'mulukhiya-toot-proxy/logger'

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
