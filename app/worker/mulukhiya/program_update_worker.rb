module Mulukhiya
  class ProgramUpdateWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def initialize
      @config = Config.instance
      @http = HTTP.new
      @logger = Logger.new
    end

    def perform
      File.write(path, @http.get(@config['/programs/url']).to_s)
    rescue Ginseng::ConfigError => e
      @logger.error(class: self.class.to_s, error: e.message)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/programs.json')
    end
  end
end
