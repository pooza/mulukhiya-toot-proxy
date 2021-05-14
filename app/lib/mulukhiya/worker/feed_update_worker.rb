module Mulukhiya
  class FeedUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false

    def initialize
      @storage = RenderStorage.new
    end

    def perform
      bar = ProgressBar.create(total: custom_feeds.count) if Environment.rake?
      custom_feeds.each do |entry|
        command = create_command(entry)
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

    def create_command(params)
      params.deep_symbolize_keys!
      command = CommandLine.new(params[:command])
      command.dir = params[:dir] || Environment.dir
      command.env = params[:env] if params[:env]
      return command
    end
  end
end
