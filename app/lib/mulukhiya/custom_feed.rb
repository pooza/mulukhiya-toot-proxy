module Mulukhiya
  class CustomFeed
    include Singleton
    include Package
    attr_accessor :storage

    def update
      bar = ProgressBar.create(total: CustomFeed.count)
      CustomFeed.entries.each do |entry|
        renderer = create(entry)
        renderer.command.exec
        raise renderer.command.stderr unless renderer.command.status.zero?
        renderer.entries = JSON.parse(renderer.command.stdout)
        renderer.save
      rescue => e
        logger.error(error: e, feed: entry)
      ensure
        bar&.increment
      end
      bar&.finish
    end

    def create(entry)
      renderer = RSS20FeedRenderer.new(entry)
      renderer.command = CommandLine.create(entry)
      return renderer
    end

    def self.count
      return entries.count
    end

    def self.entries
      return config['/feed/custom'].map do |entry|
        entry.deep_stringify_keys!
        entry['dir'] ||= Environment.dir
        entry['title'] ||= entry['path']
        entry
      end
    end

    private

    def initialize
      @storage = RenderStorage.new
    end
  end
end
