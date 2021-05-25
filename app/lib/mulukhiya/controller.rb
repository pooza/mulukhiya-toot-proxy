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

    def name
      return self.class.to_s.split('::').last.sub(/Controller$/, '').underscore
    end

    def token
      return nil
    end

    def command
      unless @command
        command_entry ||= command_entries.find do |entry|
          entry['path'] == request.path.sub(Regexp.new("^#{path_prefix}/"), '')
        end
        return nil unless command_entry
        @command = CommandLine.new(command_entry['command'])
        @command.dir = command_entry['dir'] || Environment.dir
        @command.env = command_entry['env'] if command_entry['env']
      end
      return @command
    end

    def self.webhook_entries
      return nil
    end

    private

    def command_entries
      return config["/#{name}/custom"]
    end

    def path_prefix
      return '' if Environment.test?
      return "/mulukhiya/#{name}"
    end
  end
end
