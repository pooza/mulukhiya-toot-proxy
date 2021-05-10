module Mulukhiya
  class FeedUpdateWorker
    include Sidekiq::Worker
    include Package
    include SNSMethods
    sidekiq_options retry: false, lock: :until_executed

    def perform
      config['/feed/custom'].each do |entry|
        command = create_command(entry)
        command.exec
        raise Ginseng::Error, command.stderr unless command.status.zero?
        renderer = RSS20FeedRenderer.new(entry)
        renderer.entries = JSON.parse(command.stdout)
        storage.setex(command, config['/feed/cache/ttl'], renderer)
      rescue => e
        logger.error(error: e, feed: entry)
      end
    end

    def create_command(params)
      command = CommandLine.new(params['command'])
      command.dir = params['dir'] || Environment.dir
      command.env = params['env'] if params['env']
      return command
    end

    def storage
      @storage ||= RenderStorage.new
      return @storage
    end
  end
end
