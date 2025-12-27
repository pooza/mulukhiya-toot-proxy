module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    set :root, Environment.dir
    enable :method_override

    before do
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = token
    rescue => e
      e.log
      @sns.token = nil
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      @renderer = default_renderer_class.new
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

    private

    def path_prefix
      return '' if Environment.test?
      return "/mulukhiya/#{name}"
    end
  end
end
