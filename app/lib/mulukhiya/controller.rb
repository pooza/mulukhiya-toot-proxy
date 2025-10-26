require 'sinatra/base'

module Mulukhiya
  class Controller < Sinatra::Base
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    set :root, Environment.dir
    set :host_authorization, {permitted_hosts: []}
    enable :method_override

    def initialize
      super
      @sns = sns_class.new
    end

    before do
      @renderer = Ginseng::Web::JSONRenderer.new
      @body = request.body.read.to_s
      @headers = request.env.select {|k, _v| k.start_with?('HTTP_')}.transform_keys do |k|
        k.sub(/^HTTP_/, '').downcase.gsub(/(^|_)\w/, &:upcase).tr('_', '-')
      end
      @params = params.deep_symbolize_keys
      if request.media_type == 'application/json'
        @params.merge!(JSON.parse(@body).deep_symbolize_keys)
      end
      @sns.token = token
      logger.info(request: {
        method: request.request_method,
        path: request.path,
        params: @params,
        remote: request.ip,
      })
      @reporter = Reporter.new
    rescue => e
      e.log
      @sns.token = nil
    end

    after do
      status @renderer.status
      content_type @renderer.type
    end

    not_found do
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      @renderer = Ginseng::Web::JSONRenderer.new
      @renderer.status = e.status
      @renderer.message = e.to_h.except(:backtrace).merge(error: e.message)
      e.alert
      return @renderer.to_s
    end

    def name
      return self.class.to_s.split('::').last.sub(/Controller$/, '').underscore
    end

    alias underscore name

    def token
      return nil
    end

    def api_version
      return params[:version].sub(/^v/, '').to_i
    end
  end
end
