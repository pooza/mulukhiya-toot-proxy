module Mulukhiya
  class CustomFeed
    include Singleton
    include Package
    attr_accessor :storage

    def update
      bar = ProgressBar.create(total: count) if Environment.rake?
      CustomFeed.entries.each do |entry|
        create(entry).save
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
      unless storage[renderer.command]
        renderer.command.exec
        raise Ginseng::Error, renderer.command.stderr unless renderer.command.status.zero?
        renderer.entries = JSON.parse(renderer.command.stdout)
      end
      return renderer
    end

    def count
      return CustomFeed.entries.count
    end

    def self.entries
      return config['/feed/custom'].map do |entry|
        entry.deep_stringify_keys!
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
