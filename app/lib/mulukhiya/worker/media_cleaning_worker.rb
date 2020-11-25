module Mulukhiya
  class MediaCleaningWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    def perform
      Dir.glob(File.join(Environment.dir, 'tmp/media/*')).each do |f|
        next unless File.new(f).mtime < @config['/worker/media_cleaning/days'].days.ago
        File.unlink(f)
        @logger.info(class: self.class.to_s, message: 'delete', path: f)
      rescue => e
        @logger.error(error: e, path: f)
      end
    end
  end
end
