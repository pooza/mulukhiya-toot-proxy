module Mulukhiya
  class FeedUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, unique: :until_executed

    def initialize
      @storage = RenderStorage.new
    end

    def perform
      bar = ProgressBar.create(total: custom_feeds.count) if Environment.rake?
      custom_feeds.each do |entry|
        command = CommandLine.create(entry)
        command.exec
        raise Ginseng::Error, command.stderr unless command.status.zero?
        renderer = RSS20FeedRenderer.new(entry)
        renderer.entries = JSON.parse(command.stdout)
        @storage[command] = renderer
      rescue => e
        logger.error(error: e, feed: entry)
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def custom_feeds
      return config['/feed/custom']
    end
  end
end
