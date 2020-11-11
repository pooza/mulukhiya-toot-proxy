module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    set :root, Environment.dir
    enable :method_override

    before do
      @sns = Environment.sns_class.new
      @sns.token = token
      @reporter = Reporter.new
    rescue => e
      @logger.error(class: self.class.to_s, error: e.message)
      @sns.token = nil
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      e = Ginseng::Error.create(e)
      e.package = Package.full_name
      @renderer = default_renderer_class.new
      @renderer.status = e.status
      @renderer.message = e.to_h
      @renderer.message.delete(:backtrace)
      @renderer.message[:error] = e.message
      Slack.broadcast(e)
      @logger.error(e)
      return @renderer.to_s
    end

    def self.config
      return Config.instance
    end

    def self.webhook_entries
      return nil
    end

    private

    def token
      return @headers['Authorization'].split(/\s+/).last if @headers['Authorization']
      return params[:i] if params[:i]
      raise Ginseng::AuthError, 'Invalid token'
    end

    def response_error?
      return 400 <= @reporter.response&.code
    end

    def notify(message)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(@sns.account, message)
    end

    def status_field
      return Environment.controller_class.status_field
    end
  end
end
