module MulukhiyaTootProxy
  class CleaningMediaWorker
    include Sidekiq::Worker
    sidekiq_options retry: false

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    def perform
      Dir.glob(File.join(Environment.dir, 'tmp/media/*')).each do |f|
        next unless File.new(f).mtime < @config['/worker/cleaning_media/days'].days.ago
        File.unlink(f)
        @logger.info(worker: 'CleaningMediaWorker', action: 'delete', path: f)
      end
    rescue => e
      @logger.error(e)
    end
  end
end
