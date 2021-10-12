module Mulukhiya
  class CustomFeed
    include Package
    attr_reader :params

    def initialize(params)
      @params = params.deep_stringify_keys
      @params['dir'] ||= Environment.dir
    end

    def path
      return File.join('/', params['path'])
    end

    def fullpath
      return File.join('/mulukhiya/feed', path)
    end

    def title
      return params['title'] || params['path']
    end

    def update
      renderer.cache
    end

    def command
      @command ||= CommandLine.create(params)
      return @command
    end

    def renderer
      unless @renderer
        @renderer = RSS20FeedRenderer.new(params)
        @renderer.command = command
      end
      return @renderer
    end

    def self.count
      return all.count
    end

    def self.all
      return enum_for(__method__) unless block_given?
      config['/feed/custom'].each do |entry|
        yield CustomFeed.new(entry)
      rescue => e
        logger.error(error: e, feed: entry)
      end
    end
  end
end
