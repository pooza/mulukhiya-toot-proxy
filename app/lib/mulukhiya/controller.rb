module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    include SNSMethods
    set :root, Environment.dir
    enable :method_override

    before do
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = token
    rescue => e
      logger.error(error: e)
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
      Event.new(:alert).dispatch(e)
      logger.error(error: e)
      return @renderer.to_s
    end

    def token
      return nil
    end

    def self.webhook_entries
      return nil
    end

    def self.create_status_uri(src)
      dest = TootURI.parse(src.to_s)
      dest = NoteURI.parse(dest) unless dest&.valid?
      return dest if dest.valid?
    end
  end
end
